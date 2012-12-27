-module({{appid}}).
-include("{{appid}}.hrl").
-include_lib("riak_core/include/riak_core_vnode.hrl").

-export([
         ping/0,
	 get/1,
	 set/2,
	 list/0
        ]).

-ignore_xref([
              ping/0,
              get/1,
	      set/2,
	      list/0
             ]).

%% Public API

%% @doc Pings a random vnode to make sure communication is functional
ping() ->
    DocIdx = riak_core_util:chash_key({<<"ping">>, term_to_binary(now())}),
    PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, {{appid}}),
    [{IndexNode, _Type}] = PrefList,
    riak_core_vnode_master:sync_spawn_command(IndexNode, ping, {{appid}}_vnode_master).

get(Key) ->
    {{appid}}_entity_read_fsm:start(
      {
       {{appid}}_vnode, 
       {{appid}}
      },
      get, Key
     ).

list() ->
    {{appid}}_entity_coverage_fsm:start(
      {
       {{appid}}_vnode, 
       {{appid}}
      },
      list
     ).


set(Key, Value) ->
    {{appid}}_entity_write_fsm:write(
      { 
       {{appid}}_vnode, 
       {{appid}}
      }, Key, set, Value).
