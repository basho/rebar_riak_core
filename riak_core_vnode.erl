-module({{appid}}_vnode).
-behaviour(riak_core_vnode).

-include("{{appid}}.hrl").

-include_lib("riak_core/include/riak_core_vnode.hrl").

-export([start_vnode/1,
         init/1,
         terminate/2,
         handle_command/3,
         is_empty/1,
         delete/1,
         handle_handoff_command/3,
         handoff_starting/2,
         handoff_cancelled/1,
         handoff_finished/2,
         handle_handoff_data/2,
         encode_handoff_item/2,
         handle_coverage/4,
         handle_exit/3]).

-export([get/3, list/2, set/4]).


-ignore_xref([
	      start_vnode/1,
	      get/3, list/2, set/4
             ]).

-record(state, {partition,
		node,
		keys}).

-define(MASTER, {{appid}}_vnode_master).

%% API
start_vnode(I) ->
    riak_core_vnode_master:get_vnode_pid(I, ?MODULE).

init([Partition]) ->
    {ok, #state { partition=Partition,
		  node = node(),
		  keys = dict:new()}}.


get(Preflist, ReqID, Key) ->
    riak_core_vnode_master:command(Preflist,
				   {get, ReqID, Key},
				   {fsm, undefined, self()},
				   ?MASTER).

list(Preflist, ReqID) ->
    riak_core_vnode_master:coverage(
      {list, ReqID},
      Preflist,
      all,
      {fsm, undefined, self()},
      ?MASTER).

set(Preflist, ReqID, Key, Value) ->
    riak_core_vnode_master:command(Preflist,
                                   {set, ReqID, Key, Value},
				   {fsm, undefined, self()},
                                   ?MASTER).

%% Sample command: respond to a ping
handle_command(ping, _Sender, State) ->
    {reply, {pong, State#state.partition}, State};

handle_command({repair, undefined, Key, Obj}, _Sender, #state{keys=Keys0}=State) ->
    Keys1 = dict:store(Key, Obj, Keys0),
    {noreply, State#state{keys = Keys1}};

handle_command({get, ReqID, Key}, _Sender, #state{keys=Keys, partition=Partition, node=Node} = State) ->
    Res = case dict:find(Key, Keys) of
	      error ->
		  {ok, ReqID, {Partition,Node}, not_found};
	      {ok, V} ->
		  {ok, ReqID, {Partition,Node}, V}
	  end,
    {reply, Res, State};

handle_command({set, {ReqID, Coordinator}, Key, Value}, _Sender,
	       #state{keys=Keys0} = State) ->
    case dict:find(Key, Keys0) of
	error ->
	    Val0 = statebox:new(fun {{appid}}_entity_state:new/0),
	    Val1 = statebox:modify({fun {{appid}}_entity_state:set/2, [Value]}, Val0),
	    VC0 = vclock:fresh(),
	    VC = vclock:increment(Coordinator, VC0),
	    Obj = #{{appid}}_obj{val=Val1, vclock=VC},
	    Keys1 = dict:store(Key, Obj, Keys0),
	    {reply, {ok, ReqID}, State#state{keys=Keys1}};
	{ok, #{{appid}}_obj{val=Val0} = O} ->
	    Val1 = statebox:modify({fun {{appid}}_entity_state:set/2, [Value]}, Val0),
	    Val2 = statebox:expire(?STATEBOX_EXPIRE, Val1),
	    Obj = {{appid}}_obj:update(Val2, Coordinator, O),
	    Keys1 = dict:store(Key, Obj, Keys0),
	    {reply, {ok, ReqID}, State#state{keys=Keys1}}
    end;

handle_command(Message, _Sender, State) ->
    ?PRINT({unhandled_command, Message}),
    {noreply, State}.

handle_handoff_command(?FOLD_REQ{foldfun=Fun, acc0=Acc0}, _Sender, State) ->
    Acc = dict:fold(Fun, Acc0, State#state.keys),
    {reply, Acc, State};

handle_handoff_command(_Message, _Sender, State) ->
    {noreply, State}.

handoff_starting(_TargetNode, State) ->
    {true, State}.

handoff_cancelled(State) ->
    {ok, State}.

handoff_finished(_TargetNode, State) ->
    {ok, State}.

handle_handoff_data(Data, State) ->
    {Key, Value} = binary_to_term(Data),
    Keys = dict:store(Key, Value, State#state.keys),
    {reply, ok, State#state{keys = Keys}}.

encode_handoff_item(Key, Value) ->
    term_to_binary({Key, Value}).

is_empty(State) ->
    case dict:size(State#state.keys) of
	0 ->
	    {true, State};
	_ ->
	    {false, State}
    end.

delete(State) ->
    {ok, {ok, State#state{keys=dict:new()}}}.

handle_coverage({list, ReqID}, _KeySpaces, _Sender, 
		#state{keys=Keys, partition=Partition, node=Node} = State) ->
    Res = {ok, ReqID, {Partition,Node}, dict:fetch_keys(Keys)},
    {reply, Res, State};

handle_coverage(_Req, _KeySpaces, _Sender, State) ->
    {stop, not_implemented, State}.

handle_exit(_Pid, _Reason, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
