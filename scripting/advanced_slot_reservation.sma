/* Sublime AMXX Editor v4.2 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#if !defined MAX_IP_LENGTH 
#define MAX_IP_LENGTH 16
#endif

#define PLUGIN  "[Advanced Slot Reservation]"
#define VERSION "1.0"
#define AUTHOR  "Shadows Adi"

new Array:g_aReservedIPs
new g_iMaxPlayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	create_cvar("adv_slot_reservation", AUTHOR, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)

	if(!is_rehlds())
	{
		set_fail_state("ReHLDS API Not Found!")
	}

	RegisterHookChain(RH_SV_ConnectClient, "SV_ClientConnect_Pre")

	g_aReservedIPs = ArrayCreate(MAX_IP_LENGTH)

	g_iMaxPlayers = get_member_game(m_nMaxPlayers)

	/* Setting this cvar to let the player trigger SV_ConnectClient() function, followed by SV_ConnectClient_internal() function, finally checking if there is
	any player slot free in SV_FindEmptySlot() function

		SV_ConnectClient:				https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2261-L2264
		SV_ConnectClient_internal : 	https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2266
		SV_FindEmptySlot call: 			https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2385-L2387
		SV_FindEmptySlot function: 		https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2236-L2259 
	*/
	
	set_pcvar_num(get_cvar_pointer("sv_visiblemaxplayers"), g_iMaxPlayers + 1 /* We just need one more slot */)
}

public OnConfigsExecuted()
{
	ReadFile()
}

ReadFile()
{
	/* Basic reading contents of a file */

	new szConfigsDir[256], szFileName[256]
	get_localinfo("amxx_configsdir", szConfigsDir, charsmax(szConfigsDir))
	formatex(szFileName, charsmax(szFileName), "%s/SlotReservation.ini", szConfigsDir)

	new iFile = fopen(szFileName, "rt")

	if(iFile)
	{
		new szData[MAX_IP_LENGTH + 4]

		while(fgets(iFile, szData, charsmax(szData)))
		{
			trim(szData)

			if(szData[0] == '#' || szData[0] == EOS || szData[0] == ';')
				continue

			replace_all(szData, charsmax(szData), "^"", "")
			replace_all(szData, charsmax(szData), ":", "")

			ArrayPushString(g_aReservedIPs, szData)
		}
	}
	fclose(iFile)
}

public plugin_end()
{
	ArrayDestroy(g_aReservedIPs)
}

public SV_ClientConnect_Pre(id)
{
	new iPlayers = get_playersnum_ex()

	/* If connected players num is lower than 32, stop the function */
	if(iPlayers != g_iMaxPlayers)
	{
		return
	}

	new szIP[MAX_IP_LENGTH], szTemp[MAX_IP_LENGTH], bool:bFound
	
	/* Retrieving connecting player's IP address */
	rh_get_net_from(szIP, charsmax(szIP))

	for(new i; i < ArraySize(g_aReservedIPs); i++)
	{
		ArrayGetString(g_aReservedIPs, i, szTemp, charsmax(szTemp))

		/* Searching for player's IP address in array. If found, then the function can begin it's verification proccess */
		if(equali(szIP, szTemp, strlen(szIP)))
		{
			bFound = true
			break
		}
	}

	if(!bFound)
	{
		return
	}
	else
	{
		new iCount 

		again:
		/* Getting a random player index from connected players */
		new iRand = random_num(1, get_playersnum_ex())

		/* Checking if user is not admin, as well, to avoid infinite loop, we check this three times */
		if((is_user_admin(iRand) || !is_user_connected(iRand)) && iCount < 3)
		{
		    iCount++
		    goto again
		}

		rh_drop_client(iRand, "Kicked due reserved slot!")
	}
}
