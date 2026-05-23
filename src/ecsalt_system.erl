-module(ecsalt_system).

-include("ecsalt.hrl").

-export([register/2, register/3, unregister/2]).

-spec register(system(), world()) -> {ok, world()}.
register(Callback, World) ->
    register(Callback, 0, World).

-spec register(system(), integer(), world()) -> {ok, world()}.
register(Callback, Priority, World) ->
    #world{systems = S} = World,
    S0 =
        case lists:keytake(Callback, 2, S) of
            false ->
                S;
            {value, _Tuple, SRest} ->
                % Replace the current value instead
                SRest
        end,
    S1 = lists:keysort(1, [{Priority, Callback} | S0]),
    {ok, World#world{systems = S1}}.

-spec unregister(system(), world()) -> {ok, world()}.
unregister(Callback, World) ->
    #world{systems = S} = World,
    S1 = lists:keydelete(Callback, 2, S),
    {ok, World#world{systems = S1}}.
