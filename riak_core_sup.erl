-module({{appid}}_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    VMaster = { {{appid}}_vnode_master,
                  {riak_core_vnode_master, start_link, [{{appid}}_vnode]},
                  permanent, 5000, worker, [riak_core_vnode_master]},

    WriteFSMs = { {{appid}}_entity_write_fsm_sup,
		{ {{appid}}_entity_write_fsm_sup, start_link, []},
		permanent, infinity, supervisor, [{{appid}}_entity_write_fsm_sup]},

    CoverageFSMs = { {{appid}}_entity_coverage_fsm_sup,
		     { {{appid}}_entity_coverage_fsm_sup, start_link, []},
		    permanent, infinity, supervisor, [{{appid}}_entity_coverage_fsm_sup]},
    
    ReadFSMs = {
      {{appid}}_entity_read_fsm_sup,
      {
	{{appid}}_entity_read_fsm_sup, start_link, []},
      permanent, infinity, supervisor, [{{appid}}_entity_read_fsm_sup]},
    
    { ok,
        { {one_for_one, 5, 10},
          [VMaster, WriteFSMs, ReadFSMs, CoverageFSMs]}}.
