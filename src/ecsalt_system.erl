-module(ecsalt_system).

-include("ecsalt.hrl").

-export([
    new/2,
    new/3,
    delete/2
]).

-spec new(system(), world()) -> {ok, world()}.
new(Callback, World) ->
    new(Callback, 0, World).

-spec new(system(), integer(), world()) -> {ok, world()}.
new(Callback, Priority, World) ->
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

-spec delete(system(), world()) -> {ok, world()}.
delete(Callback, World) ->
    #world{systems = S} = World,
    S1 = lists:keydelete(Callback, 2, S),
    {ok, World#world{systems = S1}}.
