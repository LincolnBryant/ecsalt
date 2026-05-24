-record(world, {
    systems = [] :: [{term(), system()}],
    entities :: ets:tid(),
    components :: ets:tid()
}).

-opaque world() :: #world{}.
-export_type([world/0]).
-type component() :: {term(), term()}.
-type entity() :: {term(), [component()]}.
-export_type([entity/0]).
-type system() :: {mfa() | fun()}.
-type id() :: identifier().
