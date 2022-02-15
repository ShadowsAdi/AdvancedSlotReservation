/* Sublime AMXX Editor v4.2 */

#include <amxmodx>
#include <advanced_slot_res>

#define PLUGIN  "[Advanced Slot Reservation] API Test"
#define VERSION "1.0"
#define AUTHOR  "Shadows Adi"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
}

public player_kick_pre(id, szPlayerData[PlayerData])
{
	#if defined USE_REAPI
	server_print("player_kick_pre(): id (%d) Name: (%s) Password: (%s) IP: (%s)^n", id, szPlayerData[szName], szPlayerData[szPassword], szPlayerData[szIP])
	#else 
	server_print("player_kick_pre(): id (%d) Name: (%s) Password: (%s)^n", id, szPlayerData[szName], szPlayerData[szPassword])
	#endif
	return SLOT_KICK_NO
}

public player_kick_post(id, szPlayerData[PlayerData])
{
	#if defined USE_REAPI
	server_print("player_kick_post(): id (%d) Name: (%s) Password: (%s) IP: (%s)^n", id, szPlayerData[szName], szPlayerData[szPassword], szPlayerData[szIP])
	#else 
	server_print("player_kick_pre(): id (%d) Name: (%s) Password: (%s)^n", id, szPlayerData[szName], szPlayerData[szPassword])
	#endif
}

public player_check_playtime(iPlayers[MAX_PLAYERS], iNum)
{
	server_print("iNum: %d", iNum)
	
	/* Assigning the newest player slot and the oldest player slot into a temporarily variable */
	new temp[2]
	temp[0] = iPlayers[0]
	temp[1] = iPlayers[iNum - 1]

	server_print("Before switch: First entry: (%n) Last Entry: (%n)", iPlayers[0], iPlayers[iNum - 1])

	/* Change the newest player slot with the oldest player slot */
 	iPlayers[0] = temp[1]
	iPlayers[iNum - 1] = temp[0]

	server_print("After switch: First entry: (%n) Last Entry: (%n)^n", iPlayers[0], iPlayers[iNum - 1])
}