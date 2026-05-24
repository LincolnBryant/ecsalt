ECSalt - Entity Component System for Erlang
===========================================

ECSalt (pronounced Exalt) is an Entity-Component-System-like library for Erlang
applications.

## Using ECSalt
For a contrived example, we'll go through adding a system that makes a monster 
take damage if they are on fire.

First start ECSalt:
```erlang
1> World = ecsalt:new().
{world,[],#Ref<0.1960388004.2533228547.251798>,
       #Ref<0.1960388004.2533228547.251799>}
```

Suppose we have a fireplace and it has the burning state. The entity ID is an
arbitrary reference, We represent the Fireplace with a unique reference:
```erlang
2> Fireplace = make_ref().
3> ecsalt_component:put([{burning, true}], Fireplace, World).
ok
```

Now let's imagine a goblin-cat snuggles a bit too close to the fireplace and
starts smoldering:
```erlang
4> GoblinCat = make_ref().
5> ecsalt_component:put([{burning, true}], GoblinCat, World).
ok
```

The put/3 function takes a list of components, so we can add several components
at once:
```erlang
6> ecsalt_component:put([{hp, 35}, {color, green}, {brain_cells, 1}], GoblinCat, World).
ok
```

Now suppose want to check for all entities that are on fire and have some
health points (HP). We can use the `match/2` function in the component module
to *only* return the functions that match all required components. For example,
our radiant goblin-cat matches here, but the fireplace does not because it
doesn't have HP:
```erlang
7> ecsalt_component:match([hp, burning], World).
[{#Ref<0.1707322081.1329856513.118511>,
  [{burning,true},{hp,35},{color,green},{brain_cells,1}]}]
```

We can also define systems that will act on collections of components. Systems
must be one of: `fun` with arity of 2, a `mfa()` tuple of the form {Module,
Fun, 2}. Suppose we have a system that checks if the cat is on fire and updates
their HP accordingly. We define a fun that reports the critter's status, and
wrap that in another fun that matches the required callback for an ECSalt
system.
```erlang
8> Report = fun({ID, Components}) ->
      HP = proplists:get_value(hp, Components),
      case HP of
        Value when Value =< 0 ->
            io:format("Kitty is cooked!~n");
        _ -> 
            io:format("The goblin-cat smolders cluelessly...~n")
      end
    end.
#Fun<erl_eval.41.39164016>
9> System = 
        fun(_Data, World) ->
            Matches = ecsalt_component:match([hp, burning], World),
            lists:foreach(Report, Matches)
        end.
#Fun<erl_eval.42.130099583>
```

The system should now be registered with ECSalt:
```erlang
10> {ok, World1} = ecsalt_system:register(System, World)
{ok,{world,[{0,#Fun<erl_eval.42.130099583>}],
           #Ref<0.1707322081.1329987585.118543>,
           #Ref<0.1707322081.1329987585.118544>}}
```
Note that World changed here. We are updating a map in the World record, rather
than a mutable ETS table, so we have to save this as World1.

You can trigger the system whenever you like via proc/1 (short for
process, a term borrowed from multi-user dungeons). We pass an empty list as
extra data -- none of our systems use it.
```erlang
12> ecsalt:proc([], World1).
The goblin-cat cluelessly smolders...
[{#Fun<erl_eval.41.130099583>,ok}]
```

Our goblin-cat is smoldering away, but nothing changes the state of the
critter. We want to reduce the HP of any burning creatures every time the
system triggers (i.e., procs). This time we can use the `foreach/3` function to
simplify things a bit:
```erlang
BurnSystem = 
    fun(_Data, World) ->
        ecsalt_component:foreach([hp, burning], 
            fun(ID, _Components) ->
                ecsalt_component:update(hp, fun(HP) -> HP - 10 end, ID, World),
                io:format("Sizzle.. hiss.. crackle..~n")
            end, 
        World)
    end,
ecsalt_system:register(BurnSystem, World).
```

If we run the `proc` again, representing a game, tick, we see the clueless
critter losing HP and, finally, becoming easy dinner:
```erlang

8> ecsalt:proc([], World2).
Sizzle.. hiss.. crackle..
The goblin-cat cluelessly smolders...
[akao{#Fun<erl_eval.41.130099583>,ok},
 {#Fun<erl_eval.41.130099583>,ok}]
9> ecsalt:proc([], World2).
Sizzle.. hiss.. crackle..
The goblin-cat cluelessly smolders...
[{#Fun<erl_eval.41.130099583>,ok},
 {#Fun<erl_eval.41.130099583>,ok}]
10> ecsalt:proc([], World2).
Sizzle.. hiss.. crackle..
The goblin-cat cluelessly smolders...
[{#Fun<erl_eval.41.130099583>,ok},
 {#Fun<erl_eval.41.130099583>,ok}]
11> ecsalt:proc([], World2).
Sizzle.. hiss.. crackle..
Kitty is cooked!
[{#Fun<erl_eval.41.130099583>,ok},
 {#Fun<erl_eval.41.130099583>,ok}]
```
