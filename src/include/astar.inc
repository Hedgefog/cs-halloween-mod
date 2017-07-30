#if defined _AStar_included
	#endinput
#endif
#define _AStar_included

/** Array:AStar(Float:Start[3], Float:Goal[3], StepSize = 30, Ignore = IGNORE_MONSTERS, IgnoreID = 0, GroundDistance = 35, Heuristic = 50);
 *
 * Finds a path between Start and Goal.
 *
 *
 * Parameters:
 *
 *	Float:Start[3]
 *		Starting position.
 *
 *	Float:Goal[3]
 *		Hopefully the end position.
 *
 *	(Optional) StepSize = 30
 *		Defines how far between each step to take in a pattern of -X + X in all three dimensions. This means that diagonally, the step will be longer.
 *
 *	(Optional) Ignore = IGNORE_MONSTERS
 *		Flags for the traceline check.
 *
 *	(Optional) IgnoreID = 0
 *		id of the calling player if IGNORE_MONSTERS is not set. Again, this is for the traceline.
 *
 *	(Optional) GroundDistance = 35
 *		Set the maximum distance from the ground for the point to be accepted as valid. If set to 0 this check is disabled, meaning pathfinding for flying entities.
 *
 *	(Optional) Heuristic = 50
 *		Optimization parameter. Decides how much importance the distance from the target has.
 *		Higher values might result in a faster execution but may also result in a suboptimal path.
 *
 * Returns a handle to a dynamic array that will contain each step between start and goal.
 * On failure it will return Invalid_Array.
**/
native Array:AStar(Float:Start[3], Float:Goal[3], StepSize = 30, Ignore = IGNORE_MONSTERS, IgnoreID = 0, GroundDistance = 35, Heuristic = 50, ...);

/** AStarThreaded(Float:Start[3], Float:Goal[3], Handler[], StepSize = 30, Ignore = IGNORE_MONSTERS, IgnoreID = 0, GroundDistance = 35, Heuristic = 50);
 *
 * Finds a path between Start and Goal.
 *
 *
 * Parameters:
 *
 *	Float:Start[3]
 *		Starting position.
 *
 *	Float:Goal[3]
 *		Hopefully the end position.
 *
 *	Handler[]
 *		The function that will be called once the pathfinding is done.
 *		The format of the handler function should be as such:
 *			public PathDone(Index, Array:hPath, Float:Distance, NodesAdded, NodesValidated, NodesCleared)
 *
 *	(Optional) StepSize = 30
 *		Defines how far between each step to take in a pattern of -X + X in all three dimensions. This means that diagonally, the step will be longer.
 *
 *	(Optional) Ignore = IGNORE_MONSTERS
 *		Flags for the traceline check.
 *
 *	(Optional) IgnoreID = 0
 *		id of the calling player if IGNORE_MONSTERS is not set. Again, this is for the traceline.
 *
 *	(Optional) GroundDistance = 35
 *		Set the maximum distance from the ground for the point to be accepted as valid. If set to 0 this check is disabled, meaning pathfinding for flying entities.
 *
 *	(Optional) Heuristic = 50
 *		Optimization parameter. Decides how much importance the distance from the target has.
 *		Higher values might result in a faster execution but may also result in a suboptimal path.
 *
 * Returns a que index that can be used in the handler to identify which path is complete.
 * On failure it will return -1.
**/
native AStarThreaded(Float:Start[3], Float:Goal[3], Handler[], StepSize = 30, Ignore = IGNORE_MONSTERS, IgnoreID = 0, GroundDistance = 35, Heuristic = 50, ...);



// The following functions are only used with the AStar() function, not AStarThreaded().

/**
 * AStar_GetDistance()
 *
 * Returns the distance of the last non-threaded path.
**/
native Float:AStar_GetDistance();

/**
 * AStar_GetNodesAdded()
 *
 * Returns the ammount of nodes that were created from the last non-threaded path.
**/
native AStar_GetNodesAdded();

/**
 * AStar_GetNodesValidated()
 *
 * Returns the ammount of nodes that were validated from the last non-threaded path.
**/
native AStar_GetNodesValidated();

/**
 * AStar_GetNodesValidated()
 *
 * Returns the ammount of nodes that were cleared from the last non-threaded path.
**/
native AStar_GetNodesCleared();


native AStarAbort(Index);