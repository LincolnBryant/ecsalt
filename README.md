ECSalt - Entity Component System for Erlang
===========================================

[![Casual Maintenance Intended](https://casuallymaintained.tech/badge.svg)](https://casuallymaintained.tech/)


ECSalt (pronounced Exalt) is an Entity-Component-System-like library for Erlang
applications.

## Using ECSalt
To demonstate how to use ECSalt, we'll go through adding a system that makes a monster 
take damage if they are on fire.

### Creating the ECS World
First start a new ECSalt "world". Worlds are collections of entities,
components, and systems. You may start any number of ECSalt worlds, up to the
half of the maximum number of ETS tables in your Erlang runtime.
```erlang
1> World = ecsalt:new().
{world,[],#Ref<0.3056694120.667287557.234440>,
       #Ref<0.3056694120.667287557.234441>}
```

### Dynamically create entities with attached components
Suppose we have a fireplace and it has the burning state. The entity ID is an
arbitrary reference, We represent the Fireplace with a unique reference:
```erlang
2> Fireplace = make_ref().
```

Then we put/3 it into the ECSalt world. Note that functions updating the world
will always return a world() record.
```erlang
3> ecsalt_component:put([{burning, true}], Fireplace, World).
{world,[],#Ref<0.3056694120.667287557.234440>,
       #Ref<0.3056694120.667287557.234441>}
```

Now let's imagine a goblin-cat snuggles a bit too close to the fireplace and
starts smoldering:
```erlang
4> GoblinCat = make_ref().
5> ecsalt_component:put([{burning, true}], GoblinCat, World).
{world,[],#Ref<0.3056694120.667287557.234440>,
       #Ref<0.3056694120.667287557.234441>}
```

The put/3 function takes a list of components, so we can add several components
at once. 
```erlang
6> ecsalt_component:put([{hp, 35}, {color, green}, {brain_cells, 1}], GoblinCat, World).
{world,[],#Ref<0.3056694120.667287557.234440>,
       #Ref<0.3056694120.667287557.234441>}
```
Any component put/3 into the ECS will overwrite previous components for the
same entity.

### Matching on component lists
Now suppose want to check for all entities that are on fire and have some
health points (HP). We can use the `match/2` function in the component module
to *only* return the functions that match all required components. For example,
our radiant goblin-cat matches here, but the fireplace does not because it
doesn't have HP:
```erlang
7> ecsalt_component:match([hp, burning], World).
[{#Ref<0.3056694120.667156485.234478>,
  [{hp,35},{color,green},{brain_cells,1},{burning,true}]}]
```

### Registering systems
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
10> World1 = ecsalt_system:register(System, World)
{world,[{0,#Fun<erl_eval.41.130099583>}],
       #Ref<0.3056694120.667287557.234440>,
       #Ref<0.3056694120.667287557.234441>}
```
Note that we have to update the World binding here. You should always treat
World as an opaque object, but when adding/removing systems you _must_ do so.

### Activating systems
You can trigger the system whenever you like via proc/1 (short for
process, a term borrowed from multi-user dungeons). We pass an empty list as
extra data -- none of our systems use it.
```erlang
12> ecsalt:proc([], World1).
The goblin-cat cluelessly smolders...
[{#Fun<erl_eval.41.130099583>,ok}]
```

### Using the foreach construction
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

### Demo
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
