/* Sublime AMXX Editor v4.2 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#if !defined MAX_NAME_LENGTH 
#define MAX_NAME_LENGTH 32
#endif

#if !defined MAX_IP_LENGTH
#define MAX_IP_LENGTH 16
#endif

#define PLUGIN  "[Advanced Slot Reservation]"
#define VERSION "1.1"
#define AUTHOR  "Shadows Adi"

new const name_field[] 		= 			"name"

new const INCLUDE_ADMINS[] 	=			"INCLUDE_ADMINS"
new const INCLUDE_BOTS[] 	=			"INCLUDE_BOTS"
new const RELOAD_FILE[] 	=			"RELOAD_FILE_ACCESS"

enum _:Enum_Data
{
	szBuffer[MAX_NAME_LENGTH],
	szValue[3]
}

enum _:Enum_PData
{
	szIP[MAX_IP_LENGTH],
	szName[MAX_NAME_LENGTH]
}

enum
{
	iSettings = 1,
	iReservedSlots
}

enum _:Enum_Settings
{
	bool:IncludeAdmins,
	bool:IncludeBots,
	szAccess[2]
}

new Array:g_aReservedSlot
new g_iMaxPlayers
new g_szSettings[Enum_Settings]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("adv_slot_reservation", AUTHOR, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)

	if(!is_rehlds())
	{
		set_fail_state("ReHLDS API Not Found!")
	}

	RegisterHookChain(RH_SV_ConnectClient, "SV_ClientConnect_Pre")

	g_aReservedSlot = ArrayCreate(Enum_Data)

	g_iMaxPlayers = get_member_game(m_nMaxPlayers)

	/* Setting this cvar to let the player trigger SV_ConnectClient() function, followed by SV_ConnectClient_internal() function, finally checking if there is
	any free player slot in SV_FindEmptySlot() function

		SV_ConnectClient:				https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2261-L2264
		SV_ConnectClient_internal : 	https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2266
		SV_FindEmptySlot call: 			https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2385-L2387
		SV_FindEmptySlot function: 		https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2236-L2259 
	*/
	
	set_pcvar_num(get_cvar_pointer("sv_visiblemaxplayers"), g_iMaxPlayers + 1 /* We just need one more slot */)
}

public plugin_cfg()
{
	ReadFile()
}

public ConCMD_Reload(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED
	}

	new iSuccess
	iSuccess = ReadFile()

	console_print(id, "%s Configuration file has been reloaded %ssuccesfully", PLUGIN, iSuccess ? "" : "un")

	return PLUGIN_HANDLED
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
		new szData[48], szTemp[Enum_Data], iSection

		while(fgets(iFile, szData, charsmax(szData)))
		{
			trim(szData)

			if(szData[0] == '#' || szData[0] == EOS || szData[0] == ';')
				continue

			if(szData[0] == '[')
			{
				iSection += 1
				continue
			}

			switch(iSection)
			{
				case iSettings:
				{
					strtok(szData, szTemp[szBuffer], charsmax(szTemp[szBuffer]), szTemp[szValue], charsmax(szTemp[szValue]), '=')
					trim(szTemp[szBuffer])
					trim(szTemp[szValue])

					if(equali(szTemp[szBuffer], INCLUDE_ADMINS))
					{
						g_szSettings[IncludeAdmins] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], INCLUDE_BOTS))
					{
						g_szSettings[IncludeBots] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], RELOAD_FILE))
					{
						copy(g_szSettings[szAccess], charsmax(g_szSettings[szAccess]), szTemp[szValue])
					}
				}
				case iReservedSlots:
				{
					parse(szData, szTemp[szBuffer], charsmax(szTemp[szBuffer]), szTemp[szValue], charsmax(szTemp[szValue]))

					replace_all(szTemp[szBuffer], charsmax(szTemp[szBuffer]), ":", "")

					ArrayPushArray(g_aReservedSlot, szTemp)
				}
			}
		}
	}
	fclose(iFile)

	static iCMD

	if(0 >= iCMD)
	{
		iCMD = register_concmd("amx_reload_slot_file", "ConCMD_Reload", read_flags(g_szSettings[szAccess]))
	}

	return 1
}

public plugin_end()
{
	ArrayDestroy(g_aReservedSlot)
}

public SV_ClientConnect_Pre(id)
{
	new iPlayers = get_playersnum_ex()

	/* If connected players num is lower than 32, stop the function */
	if(iPlayers != g_iMaxPlayers)
	{
		return
	}

	new szPlayerData[Enum_PData], eArray[Enum_Data], bool:bFound, szTemp[1024]
	
	/* Retrieving connecting player's IP address also his name to check them later... */
	rh_get_net_from(szPlayerData[szIP], charsmax(szPlayerData[szIP]))
	read_args(szTemp, charsmax(szTemp))

	new iPos = containi(szTemp, name_field)

	if(iPos != -1)
	{
		/* iPos shows the position in the string and adding 5 will skip 5 characters  : "name " */
		copyc(szPlayerData[szName], charsmax(szPlayerData[szName]), szTemp[iPos + 5], '\')
	}

	for(new i; i < ArraySize(g_aReservedSlot); i++)
	{
		ArrayGetArray(g_aReservedSlot, i, eArray, charsmax(eArray))

		/* Searching for player's reserved data in array. If found, then the function can begin it's verification proccess */
		switch(eArray[szValue][0])
		{
			case 'I':
			{
				if(equali(szPlayerData[szIP], eArray[szBuffer], strlen(szPlayerData[szIP])))
				{
					bFound = true
					break
				}
			}
			case 'N':
			{
				if(equali(szPlayerData[szName], eArray[szBuffer], strlen(szPlayerData[szName])))
				{
					bFound = true
					break
				}
			}
		}
	}

	if(bFound)
	{
		new iPlayers[MAX_PLAYERS], iNum, iPlayer, iCount, bool:bSkip[2]
		get_players(iPlayers, iNum)

		bSkip[0] = g_szSettings[IncludeAdmins]
		bSkip[1] = g_szSettings[IncludeBots]

		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[i]

			if(bSkip[0] && is_user_admin(iPlayer))
			{
				iCount++
				continue
			}

			if(bSkip[1] && (is_user_bot(iPlayer) || is_user_hltv(iPlayer)))
			{
				iCount++
				continue
			}

			iCount++
		}

		new iRandom, iLooped

		again:
		iRandom = random_num(1, iCount)

		 /* Checking if user is not admin, bot or hltv, depends on settings, as well, to avoid infinite loop, we check this three times, I think it's enough */
		if(iLooped < 3 && (!bSkip[0] && is_user_admin(iRandom) || !bSkip[1] && is_user_bot_hltv(iRandom)))
		{
			iLooped++
			goto again
		}

		rh_drop_client(iPlayers[iRandom], "Kicked due reserved slot!")
	}
}

bool:is_user_bot_hltv(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
	{
		return true 
	}

	return false
}