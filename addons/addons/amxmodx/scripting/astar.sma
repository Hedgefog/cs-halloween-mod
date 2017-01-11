#include <amxmodx>
#include <engine>
#include <fakemeta>

#define WORKERS	10
//#define DEBUG

#if defined DEBUG
	#define LOOPS_PER_THINK 1
	#define THINK_INTERVAL 0.05
	#define RGB(%0,%1,%2) ( ( ( %0 & 255 ) << 16 ) | ( ( %1 & 255 ) << 8 ) | ( %2 & 255 ) )
#else
	#define LOOPS_PER_THINK 50 // Decrease if performance is an issue. Decreasing this value will increase the time of pathfinding.
	#define THINK_INTERVAL 0.0 // Increase if performance is an issue. Increasing this value will increase the time of pathfinding.
#endif

enum NodeDataEnum {
	_Pos[3],
	_Null,
	_Parent[3],
	_Null,
	_G,
	_F,
};

enum WorkerEnum {
	Array:_hOpenSet,
	Trie:_hClosedSet,
	Trie:_hNodeData,

	_Goal[3],
	_StepSize,
	_Ignore,
	_IgnoreID,
	_GroundDistance,
	_Heuristic,

	_ArraySize,

	_NodesAdded,
	_NodesValidated,
	_NodesCleared,

	_Distance,

	_hForward,
	bool:_Active
}

new gData[WORKERS + 1][WorkerEnum];
new gWorkerEntity;

#if defined DEBUG
new g_sprite;

public plugin_precache()
	g_sprite = precache_model("sprites/laserbeam.spr");
#endif

public plugin_natives() {
	for ( new i ; i < sizeof gData ; i++ ) {
		gData[i][_hOpenSet] = _:ArrayCreate(4);
		gData[i][_hClosedSet] = _:TrieCreate();
		gData[i][_hNodeData] = _:TrieCreate();
	}

	register_native("AStar", "native_AStar");
	register_native("AStarThreaded", "native_AStarThreaded");

	register_native("AStarAbort", "native_Abort");
	
	register_native("AStar_GetDistance", "native_GetDistance");
	register_native("AStar_GetNodesAdded", "native_GetNodesAdded");
	register_native("AStar_GetNodesValidated", "native_GetNodesValidated");
	register_native("AStar_GetNodesCleared", "native_GetNodesCleared");
	
}

public plugin_init() {
	register_plugin("A* Pathfinding API", "1.2", "[ --{-@ ]");

	register_think("A* Worker", "WorkerThread");
}

public native_Abort(id, numParams) {

	new index = get_param(1);

	if ( ! ( 0 < index < sizeof gData - 1 ) )
		return;

	gData[index][_Active] = false;
}

public Array:native_AStar(id, numParams) {

	new FreeIndex = sizeof gData - 1;

	new Float:Start[3];
	new Float:Goal[3];

	get_array_f(1, Start, sizeof Start);
	get_array_f(2, Goal, sizeof Goal);

	gData[FreeIndex][_StepSize] = get_param(3);
	gData[FreeIndex][_Ignore] = get_param(4);
	gData[FreeIndex][_IgnoreID] = get_param(5);
	gData[FreeIndex][_GroundDistance] = get_param(6);
	gData[FreeIndex][_Heuristic] = abs(get_param(7)) + 1000;

	gData[FreeIndex][_NodesAdded] = 0;
	gData[FreeIndex][_NodesValidated] = 0;
	gData[FreeIndex][_NodesCleared] = 0;

	new Node[NodeDataEnum];

	Node[_Pos][0] = floatround(Start[0]);
	Node[_Pos][1] = floatround(Start[1]);
	Node[_Pos][2] = floatround(Start[2]);

	gData[FreeIndex][_Goal][0] = floatround(Goal[0]);
	gData[FreeIndex][_Goal][1] = floatround(Goal[1]);
	gData[FreeIndex][_Goal][2] = floatround(Goal[2]);

	if ( Node[_Pos][0] == 0 )
		Node[_Pos][0] = 1;
	
	if ( Node[_Pos][1] == 0 )
		Node[_Pos][1] = 1;

	gData[FreeIndex][_ArraySize] = 1;
	gData[FreeIndex][_Active] = true;

	Node[_G] = 0;
	Node[_F] = 1;

	ArrayPushArray(gData[FreeIndex][_hOpenSet], Node[_Pos]);
	TrieSetArray(gData[FreeIndex][_hNodeData], Node[_Pos], Node[_Pos], sizeof Node);

	return WorkerThread(0);
}

public native_AStarThreaded(id, numParams) {

	new FreeIndex = -1;

	for ( new i ; i < sizeof gData - 1 ; i++ ) {
		if ( ! gData[i][_Active] ) {
			FreeIndex = i;
			break;
		}
	}

	if ( FreeIndex == -1 )
		return -1;

	new Node[NodeDataEnum];

	new TempString[32];
	get_string(3, TempString, charsmax(TempString));
	gData[FreeIndex][_hForward] = CreateOneForward(id, TempString, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL, FP_CELL, FP_CELL);

	gData[FreeIndex][_StepSize] = get_param(4);
	gData[FreeIndex][_Ignore] = get_param(5);
	gData[FreeIndex][_IgnoreID] = get_param(6);
	gData[FreeIndex][_GroundDistance] = get_param(7);
	gData[FreeIndex][_Heuristic] = abs(get_param(8)) + 1000;

	gData[FreeIndex][_NodesAdded] = 0;
	gData[FreeIndex][_NodesValidated] = 0;
	gData[FreeIndex][_NodesCleared] = 0;

	/* Clearing the starting point to avoid instant fail. */

	new Float:v1[3];
	new Float:v2[3];
	new hTrace;
	new Float:flFraction;

	get_array_f(1, v1, sizeof v1);

	/* Clear Z */
	v2[0] = v1[0];
	v2[1] = v1[1];
	v2[2] = v1[2] - 99999.0;

	v1[2] += 25.0;

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_vecEndPos, v1);
	

	v1[2] += 25.0;

	engfunc(EngFunc_TraceHull, v1, v2, gData[FreeIndex][_Ignore], HULL_HEAD, gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_vecEndPos, v1);
	

	v1[2] += 15.0;
	/* Z Cleared */

	/* Clear X */
	v2[0] = v1[0] + 25.0;
	v2[1] = v1[1];
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[0] -= 25.0 - (25.0 * flFraction);

	v2[0] = v1[0] - 25.0;
	v2[1] = v1[1];
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[0] += 25.0 - (25.0 * flFraction);
	/* X Cleared */

	/* Clear Y */
	v2[0] = v1[0];
	v2[1] = v1[1] + 25.0;
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[1] -= 25.0 - (25.0 * flFraction);

	v2[0] = v1[0];
	v2[1] = v1[1] - 25.0;
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[1] += 25.0 - (25.0 * flFraction);
	/* Y Cleared */

	/* Save it */
	Node[_Pos][0] = floatround(v1[0]);
	Node[_Pos][1] = floatround(v1[1]);
	Node[_Pos][2] = floatround(v1[2]);

	/* Do exactly the same thing to the end point to improve accuracy. */

	get_array_f(2, v1, sizeof v1);

	/* Clear Z */
	v2[0] = v1[0];
	v2[1] = v1[1];
	v2[2] = v1[2] - 99999.0;

	v1[2] += 25.0;

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_vecEndPos, v1);
	

	v1[2] += 25.0;

	engfunc(EngFunc_TraceHull, v1, v2, gData[FreeIndex][_Ignore], HULL_HEAD, gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_vecEndPos, v1);
	

	v1[2] += 15.0;
	/* Z Cleared */

	/* Clear X */
	v2[0] = v1[0] + 25.0;
	v2[1] = v1[1];
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[0] -= 25.0 - (25.0 * flFraction);

	v2[0] = v1[0] - 25.0;
	v2[1] = v1[1];
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[0] += 25.0 - (25.0 * flFraction);
	/* X Cleared */

	/* Clear Y */
	v2[0] = v1[0];
	v2[1] = v1[1] + 25.0;
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[1] -= 25.0 - (25.0 * flFraction);

	v2[0] = v1[0];
	v2[1] = v1[1] - 25.0;
	v2[2] = v1[2];

	engfunc(EngFunc_TraceLine, v1, v2, gData[FreeIndex][_Ignore], gData[FreeIndex][_IgnoreID], hTrace);
	get_tr2(hTrace, TR_flFraction, flFraction);
	
	v1[1] += 25.0 - (25.0 * flFraction);
	/* Y Cleared */

	/* Save that as well */
	gData[FreeIndex][_Goal][0] = floatround(v1[0]);
	gData[FreeIndex][_Goal][1] = floatround(v1[1]);
	gData[FreeIndex][_Goal][2] = floatround(v1[2]);

	if ( Node[_Pos][0] == 0 )
		Node[_Pos][0] = 1;
	
	if ( Node[_Pos][1] == 0 )
		Node[_Pos][1] = 1;

	gData[FreeIndex][_ArraySize] = 1;
	gData[FreeIndex][_Active] = true;

	Node[_G] = 0;
	Node[_F] = 1;

	ArrayPushArray(gData[FreeIndex][_hOpenSet], Node[_Pos]);
	TrieSetArray(gData[FreeIndex][_hNodeData], Node[_Pos], Node[_Pos], sizeof Node);

	if ( ! gWorkerEntity ) {
		gWorkerEntity = create_entity("info_target");

		if ( ! gWorkerEntity ){
			log_amx("[A* API] Failed to create entity. This is bad...");
			gData[FreeIndex][_Active] = false;
			return -1;
		}
		entity_set_string(gWorkerEntity, EV_SZ_classname, "A* Worker");
	}

	entity_set_float(gWorkerEntity, EV_FL_nextthink, get_gametime() + THINK_INTERVAL);

	return FreeIndex;
}

public Array:WorkerThread(ent) {
	
	static EffectivenessLoop, WorkerIndex, TempArrayIndex, TempG, hTrace, X, Y, Z, i;
	static Float:trFraction, Float:v1[3], Float:v2[3];
	static bool:TrieExists, bool:ActuallyWorking;
	static CurNode[NodeDataEnum], TempNode[NodeDataEnum];

	ActuallyWorking = false;

	for ( WorkerIndex = 0 ; ! ent || WorkerIndex < sizeof gData ; WorkerIndex++ ) {

		if ( ! ent )
			WorkerIndex = sizeof gData - 1;

		if ( ! gData[WorkerIndex][_Active] )
			continue;

		ActuallyWorking = true;

		for ( EffectivenessLoop = 0 ; EffectivenessLoop < LOOPS_PER_THINK ; EffectivenessLoop++ ) {

			if ( ! gData[WorkerIndex][_ArraySize]) {

				gData[WorkerIndex][_Active] = false;

				if ( ! ent )
					return Invalid_Array;
				
				ExecuteForward(gData[WorkerIndex][_hForward], TempArrayIndex, WorkerIndex, Invalid_Array, 0.0, gData[WorkerIndex][_NodesAdded], gData[WorkerIndex][_NodesValidated], gData[WorkerIndex][_NodesCleared]);
				continue;
			}
			
			TempArrayIndex = 0;
			CurNode[_F] = (1<<31) - 1;
			
			//server_print("New cycle");

			for ( i = 0 ; i < gData[WorkerIndex][_ArraySize] ; i++ ) {
				
				ArrayGetArray(gData[WorkerIndex][_hOpenSet], i, TempNode[_Pos]);
				TrieGetArray(gData[WorkerIndex][_hNodeData], TempNode[_Pos], TempNode[_Pos], sizeof TempNode);
				
				if ( TempNode[_F] < CurNode[_F] ) {
					
					CurNode[_Pos][0] = TempNode[_Pos][0];
					CurNode[_Pos][1] = TempNode[_Pos][1];
					CurNode[_Pos][2] = TempNode[_Pos][2];
					
					CurNode[_Parent][0] = TempNode[_Parent][0];
					CurNode[_Parent][1] = TempNode[_Parent][1];
					CurNode[_Parent][2] = TempNode[_Parent][2];
					
					CurNode[_G] = TempNode[_G];
					CurNode[_F] = TempNode[_F];
					
					TempArrayIndex = i;

					//server_print("New best node: %d, F: %d", TempArrayIndex, CurNode[_F]);
				}
			}

			gData[WorkerIndex][_NodesValidated]++;
			
			if ( abs( CurNode[_Pos][0] - gData[WorkerIndex][_Goal][0] ) < gData[WorkerIndex][_StepSize] && abs( CurNode[_Pos][1] - gData[WorkerIndex][_Goal][1] ) < gData[WorkerIndex][_StepSize] && abs( CurNode[_Pos][2] - gData[WorkerIndex][_Goal][2] ) < gData[WorkerIndex][_StepSize] ) {
				
				new Array:hReturn = ArrayCreate(3);
				ArrayPushArray(hReturn, CurNode[_Pos]);
				gData[WorkerIndex][_Distance] = CurNode[_G];
				
				while ( CurNode[_Parent][0] && CurNode[_Parent][1] && CurNode[_Parent][2] ) {
					TrieGetArray(gData[WorkerIndex][_hNodeData], CurNode[_Parent], CurNode[_Pos], sizeof CurNode);
					ArrayPushArray(hReturn, CurNode[_Pos]);
				}
				
				gData[WorkerIndex][_ArraySize] = ArraySize(hReturn);
				
				for ( i = 0 ; i < gData[WorkerIndex][_ArraySize] / 2 ; i++ )
					ArraySwap(hReturn, i, gData[WorkerIndex][_ArraySize] - i - 1);
				
				ArrayClear(gData[WorkerIndex][_hOpenSet]);
				TrieClear(gData[WorkerIndex][_hClosedSet]);
				TrieClear(gData[WorkerIndex][_hNodeData]);
				gData[WorkerIndex][_ArraySize] = 0;
				
				gData[WorkerIndex][_Active] = false;

				if ( ! ent )
					return hReturn;
				
				ExecuteForward(gData[WorkerIndex][_hForward], TempArrayIndex, WorkerIndex, hReturn, gData[WorkerIndex][_Distance] / 100.0, gData[WorkerIndex][_NodesAdded], gData[WorkerIndex][_NodesValidated], gData[WorkerIndex][_NodesCleared]);
				continue;
			}

			TrieSetCell(gData[WorkerIndex][_hClosedSet], CurNode[_Pos], 1);
			ArrayDeleteItem(gData[WorkerIndex][_hOpenSet], TempArrayIndex);
			gData[WorkerIndex][_ArraySize]--;
			
			v1[0] = CurNode[_Pos][0] * 1.0;
			v1[1] = CurNode[_Pos][1] * 1.0;
			v1[2] = CurNode[_Pos][2] * 1.0;

			if ( gData[WorkerIndex][_GroundDistance] ) {
				v2[0] = v1[0];
				v2[1] = v1[1];
				v2[2] = v1[2] - gData[WorkerIndex][_GroundDistance];
				
				engfunc(EngFunc_TraceHull, v1, v2, gData[WorkerIndex][_Ignore], HULL_HEAD, gData[WorkerIndex][_IgnoreID], hTrace);
				get_tr2(hTrace, TR_flFraction, trFraction);

				if ( ! ( trFraction < 1.0 ) ) {

					#if defined DEBUG
						beam(v1, v2, 1.0, RGB(150,150,0));
					#endif

					continue;
				}
			}

			if ( CurNode[_Parent][0] ) {
				v2[0] = CurNode[_Parent][0] * 1.0;
				v2[1] = CurNode[_Parent][1] * 1.0;
				v2[2] = CurNode[_Parent][2] * 1.0;

				engfunc(EngFunc_TraceLine, v1, v2, gData[WorkerIndex][_Ignore], gData[WorkerIndex][_IgnoreID], hTrace);
				get_tr2(hTrace, TR_flFraction, trFraction);
				
				if ( trFraction < 1.0 ) {
					#if defined DEBUG
						beam(v1, v2, 1.0, RGB(0,255,255));
					#endif
					continue;
				}

				v1[2] += 5;
				v2[2] += 5;

				engfunc(EngFunc_TraceHull, v1, v2, gData[WorkerIndex][_Ignore], HULL_HEAD, gData[WorkerIndex][_IgnoreID], hTrace);
				get_tr2(hTrace, TR_flFraction, trFraction);

				v1[2] -= 5;
				v2[2] -= 5;
				
				if ( trFraction < 1.0 ) {
					#if defined DEBUG
						beam(v1, v2, 1.0, RGB(255,0,255));
					#endif
					continue;
				}
			}

			#if defined DEBUG
				beam(v1, v2, 10.0, RGB(255,255,255));
			#endif

			gData[WorkerIndex][_NodesCleared]++;
			
			for ( X = -1 ; X <= 1 ; X++ ) {
				
				TempNode[_Pos][0] = CurNode[_Pos][0] + X * gData[WorkerIndex][_StepSize];

				if ( TempNode[_Pos][0] == 0)
					TempNode[_Pos][0] = 1;

				v2[0] = TempNode[_Pos][0] * 1.0;
				
				for ( Y = -1 ; Y <= 1 ; Y++ ) {
					
					TempNode[_Pos][1] = CurNode[_Pos][1] + Y * gData[WorkerIndex][_StepSize];

					if ( TempNode[_Pos][1] == 0)
						TempNode[_Pos][1] = 1;

					v2[1] = TempNode[_Pos][1] * 1.0;
					
					for ( Z = -1 ; Z <= 1 ; Z++ ) {
						
						TempNode[_Pos][2] = CurNode[_Pos][2] + Z * gData[WorkerIndex][_StepSize];
						v2[2] = TempNode[_Pos][2] * 1.0;
						
						if ( TrieKeyExists(gData[WorkerIndex][_hClosedSet], TempNode[_Pos]) )
							continue;
						
						TempG = CurNode[_G] + floatround(get_distance_f(v1, v2) * 100);

						if ( TrieKeyExists(gData[WorkerIndex][_hNodeData], TempNode[_Pos]) ) {
							
							TrieGetArray(gData[WorkerIndex][_hNodeData], TempNode[_Pos], TempNode[_Pos], sizeof TempNode);

							if ( TempG >= TempNode[_G] )
								continue;
							
							TrieExists = true;
						}
						else
							TrieExists = false;
						
						if ( ! TrieExists ) {
							ArrayPushArray(gData[WorkerIndex][_hOpenSet], TempNode[_Pos]);
							gData[WorkerIndex][_ArraySize]++;
						}
						
						TempNode[_Parent][0] = CurNode[_Pos][0];
						TempNode[_Parent][1] = CurNode[_Pos][1];
						TempNode[_Parent][2] = CurNode[_Pos][2];
						
						TempNode[_G] = TempG;
						TempNode[_F] = floatround(( TempNode[_G] / 100.0 + DistWrapper(v2, gData[WorkerIndex][_Goal]) * gData[WorkerIndex][_Heuristic] / 1000.0 ) * 100);
						TrieSetArray(gData[WorkerIndex][_hNodeData], TempNode[_Pos], TempNode[_Pos], sizeof TempNode);

						gData[WorkerIndex][_NodesAdded]++;
					}
				}
			}
		}
	}

	if ( ActuallyWorking )
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + THINK_INTERVAL);

	return Invalid_Array;
}

Float:DistWrapper(Float:P1[3], P2[]) {
	static Float:fP2[3];
	fP2[0] = P2[0] * 1.0;
	fP2[1] = P2[1] * 1.0;
	fP2[2] = P2[2] * 1.0;
	return get_distance_f(P1, fP2);
}

public Float:native_GetDistance()
	return gData[sizeof gData - 1][_Distance] / 100.0;

public native_GetNodesAdded()
	return gData[sizeof gData - 1][_NodesAdded];

public native_GetNodesValidated()
	return gData[sizeof gData - 1][_NodesValidated];

public native_GetNodesCleared()
	return gData[sizeof gData - 1][_NodesCleared];

public plugin_end() {
	for ( new i ; i < sizeof gData ; i++ ) {
		ArrayDestroy(gData[i][_hOpenSet]);
		TrieDestroy(gData[i][_hClosedSet]);
		TrieDestroy(gData[i][_hNodeData]);
	}
}

#if defined DEBUG
/* PEW PEW */
stock beam(Float:origin1[3], Float:origin2[3], Float:seconds, rgb) {
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	write_coord(floatround(origin1[0]));	// start position
	write_coord(floatround(origin1[1]));
	write_coord(floatround(origin1[2]));
	write_coord(floatround(origin2[0]));	// end position
	write_coord(floatround(origin2[1]));
	write_coord(floatround(origin2[2]));
	write_short(g_sprite);	// sprite index
	write_byte(0);	// starting frame
	write_byte(10);	// frame rate in 0.1's
	write_byte(floatround(seconds*10));	// life in 0.1's
	write_byte(10);	// line width in 0.1's
	write_byte(1);	// noise amplitude in 0.01's
	write_byte(( rgb >> 16 ) & 255);	// Red
	write_byte(( rgb >> 8 ) & 255);	// Green
	write_byte(rgb & 255);	// Blue
	write_byte(127);	// brightness
	write_byte(10);	// scroll speed in 0.1's
	message_end();
}
#endif