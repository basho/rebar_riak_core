Rebar Template for Generating Riak Core Applications
=====================================================

Usage
-----

Drop these templates into `~/.rebar/templates/`:

    cp riak* ~/.rebar/templates

Verify Erlang installation (>= R15B01):

    erl -version

Start with your first app:

    mkdir firstapp
    cd firstapp
    wget http://cloud.github.com/downloads/basho/rebar/rebar && chmod u+x rebar
    ./rebar create template=riak_core appid=firstapp

Here is an excerpt of what the output should look like:

    ==> firstapp (create)
    Writing .gitignore
    Writing Makefile
    Writing README.md
    Writing rebar.config
    ...

Congratulations, you have the start of a Riak Core application that can be deployed to multiple nodes and joined together to form a multinode cluster. Lets compile and run it in console mode:

    make rel
    ./rel/firstapp/bin/firstapp console

At this point you have a single node of firstapp running. Lets test it via the erlang console:

    1> firstapp:ping().
    {pong,753586781748746817198774991869333432010090217472}

Now shut it down:

    2> q().

.. and lets test it using the cmdline, and test it via http request:

    ./rel/firstapp/bin/firstapp start
    
    ./rel/firstapp/bin/firstapp ping
    curl http://localhost:8098/firstapp/ping
    
    ./rel/firstapp/bin/firstapp stop



devrel
----------

Above we showed how to start a single node, but this isn't typically how other Riak Core based applications like Riak are tested.  Instead, there is something called a _devrel_ that allows one to easily set up a local `N`-node cluster. By defauly `N` is 4. You can change this by either editing the `Makefile` and changing `DEVNODES` to your prefered `N`, or by setting the variable `DEVNODES` before running the commands below.

Build the dev-nodes:

    make devrel

This did create 4 separate instances under the `dev/` dir; check it out:

    ls dev

Now, lets start all the nodes:

    for d in dev/dev*; do $d/bin/firstapp start; done

Verify that the nodes are up and running:

    for d in dev/dev*; do $d/bin/firstapp ping; done

You should see four `pong` replies.  At this point it is worth saying that you have four **INDIVIDUAL** firstapp nodes running.  They are **NOT** aware of each other yet. In order to form a cluster you have to _join_ the nodes. That has to be done only once. If a node, or the entire cluster, goes down it will remember the nodes it was connected to.

    for d in dev/dev{2,3,4}; do $d/bin/firstapp-admin join firstapp1@127.0.0.1; done

Finally, to make sure they really all agree on the shape of the cluster you can ask if the _ring_ is "ready."

    ./dev/dev1/bin/firstapp-admin ringready

Which returns something like:

    TRUE All nodes agree on the ring ['firstapp1@127.0.0.1','firstapp2@127.0.0.1','firstapp3@127.0.0.1'],'firstapp4@127.0.0.1']

To verify you have a 4 node cluster and to see the distribution of the ring, run the `member_status` command:

    ./dev/dev1/bin/firstapp-admin member_status

Which returns:

    ================================= Membership ==================================
    Status     Ring    Pending    Node
    -------------------------------------------------------------------------------
    valid      25.0%      --      'firstapp1@127.0.0.1'
    valid      25.0%      --      'firstapp2@127.0.0.1'
    valid      25.0%      --      'firstapp3@127.0.0.1'
    valid      25.0%      --      'firstapp4@127.0.0.1'
    -------------------------------------------------------------------------------
    Valid:4 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

Pretty cool!! Your riak-core cluster is up and running.

And in case you want to stop all the nodes:

    for d in dev/dev*; do $d/bin/firstapp stop; done

stage and stagedevrel
----------

For rapid, iterative development both `make rel` and `make devrel`
have a `stage` counterpart. Running either:

    make stage

or

    make stagedevrel

will cause the `deps` and `apps` directories to be symlinked into the
release(s) `lib` directory. This means you can edit your apps source
code, recompile it, and load it on to the running node(s). You can
either start mochiweb reloader

    reloader:start().

when attached to the node(s), which will cause any changes to be
automatically reloaded. Or attach to a running node and run

    `l(mod_name)`.

to reload a specific module.

FSMs
----

Example usage of coverage, read and writ.

* firstapp_vnode is the name of the vnode
* firstapp is the bucket and also the service name.


coverage:

    firstapp_entity_coverage_fsm:start(
      {firstapp_vnode, firstapp},
      list
     ).

read:

    firstapp_entity_read_fsm:start(
      {firstapp_vnode, firstapp},
      get, Key
     ).

write:

    firstapp_entity_write_fsm:write(
      {firstapp_vnode, firstapp},
      Key, Op, Val
    ).
