-module(ecsalt_system).
-moduledoc "Register, list, and unregister callbacks".

-include("ecsalt.hrl").

-export([register/2, register/3, unregister/2, list/1]).

-doc """
Register a callback of the form {module, fun, 2} or fun(M,N) that will accept
Data as the first argument and the World reference as the second argument.
""".
-spec register(system(), world()) -> {ok, world()}.
register(Callback, World) ->
    register(Callback, 0, World).

-doc """
The same as register/2, but priority may also be specified. Negative values are
higher priority.
""".
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

-doc """
Remove a system from the ECS world.
""".
-spec unregister(system(), world()) -> {ok, world()}.
unregister(Callback, World) ->
    #world{systems = S} = World,
    S1 = lists:keydelete(Callback, 2, S),
    {ok, World#world{systems = S1}}.

-doc """
List all registered systems and their relative priority
""".
-spec list(world()) -> [tuple()].
list(#world{systems = S}) ->
    S.
