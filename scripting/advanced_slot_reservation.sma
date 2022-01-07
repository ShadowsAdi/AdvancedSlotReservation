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

/* Engine const https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/info.h#L37 */
#define MAX_INFO_STRING 256

#define MAX_STRING 256

#define MAX_USER_INFO_PASSWORD 32

#define PLUGIN  "[Advanced Slot Reservation]"
#define VERSION "1.4"
#define AUTHOR  "Shadows Adi"

new const name_field[] 			= 			"name"

new const INCLUDE_ADMINS[] 		=			"INCLUDE_ADMINS"
new const INCLUDE_BOTS[] 		=			"INCLUDE_BOTS"
new const KICK_SPECTATOR[]		=			"KICK_SPECTATOR"
new const KICK_PLAYER_BY_PTIME[]	=		"KICK_PLAYER_BY_PLAYTIME"
new const RELOAD_FILE[] 		=			"RELOAD_FILE_ACCESS"
new const ADMIN_IMMUNITY_FLAG[] =			"ADMIN_IMMUNITY_FLAG"
new const KICK_MESSAGE[]		=			"KICK_MESSAGE"
new const USER_PASS_FIELD[]		=			"USERINFO_PASSWORD_FIELD"
new const VGUI_SUPPORT[]		=			"VGUI_SUPPORT"
new const ADMIN_SUPPORT[]		=			"ADMIN_SUPPORT"

enum _:Enum_Data
{
	szBuffer[MAX_NAME_LENGTH],
	szValue[MAX_STRING]
}

enum _:Enum_PData
{
	szIP[MAX_IP_LENGTH],
	szName[MAX_NAME_LENGTH],
	szPassword[MAX_USER_INFO_PASSWORD]
}

enum
{
	iSettings = 1,
	iReservedSlots
}

enum
{
	iNone = 0,
	iMostPlayedTime,
	iLesserPlayedTime
}

enum _:Enum_Settings
{
	bool:bIncludeAdmins,
	bool:bIncludeBots,
	szAccess[2],
	bool:bKickSpectator,
	iKickByPlayedTime,
	szImmunityFlag[2],
	szKickMessage[MAX_STRING],
	szPassField[16],
	bool:bVGUISupport,
	iAdminSupport
}

new Array:g_aReservedSlot
new g_iMaxPlayers
new g_szSettings[Enum_Settings]
new g_iPointer

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("adv_slot_reservation", AUTHOR, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)

	if(!is_rehlds())
	{
		set_fail_state("ReHLDS API Not Found!")
	}

	RegisterHookChain(RH_SV_ConnectClient, "SV_ConnectClient_Pre")

	g_aReservedSlot = ArrayCreate(Enum_Data)

	g_iMaxPlayers = get_member_game(m_nMaxPlayers)

	/* Setting this cvar to let the player trigger SV_ConnectClient() function, followed by SV_ConnectClient_internal() function, finally checking if there is
	any free player slot in SV_FindEmptySlot() function

		SV_ConnectClient:				https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2261-L2264
		SV_ConnectClient_internal : 	https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2266
		SV_FindEmptySlot call: 			https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2385-L2387
		SV_FindEmptySlot function: 		https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2236-L2259 
	*/

	g_iPointer = get_cvar_pointer("sv_visiblemaxplayers")
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

	ArrayClear(g_aReservedSlot)

	new szTemp[Enum_Data]

	if(iFile)
	{
		new szData[MAX_INFO_STRING], iSection

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
						g_szSettings[bIncludeAdmins] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], INCLUDE_BOTS))
					{
						g_szSettings[bIncludeBots] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], KICK_SPECTATOR))
					{
						g_szSettings[bKickSpectator] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], KICK_PLAYER_BY_PTIME))
					{
						g_szSettings[iKickByPlayedTime] = clamp(str_to_num(szTemp[szValue]), 0, 2)
					}
					else if(equali(szTemp[szBuffer], RELOAD_FILE))
					{
						copy(g_szSettings[szAccess], charsmax(g_szSettings[szAccess]), szTemp[szValue])
					}
					else if(equali(szTemp[szBuffer], ADMIN_IMMUNITY_FLAG))
					{
						copy(g_szSettings[szImmunityFlag], charsmax(g_szSettings[szImmunityFlag]), szTemp[szValue])
					}
					else if(equali(szTemp[szBuffer], USER_PASS_FIELD))
					{
						copy(g_szSettings[szPassField], charsmax(g_szSettings[szPassField]), szTemp[szValue])
					}
					else if(equali(szTemp[szBuffer], KICK_MESSAGE))
					{
						copy(g_szSettings[szKickMessage], charsmax(g_szSettings[szKickMessage]), szTemp[szValue])
					}
					else if(equali(szTemp[szBuffer], VGUI_SUPPORT))
					{
						g_szSettings[bVGUISupport] = bool:clamp(str_to_num(szTemp[szValue]), 0, 1)
					}
					else if(equali(szTemp[szBuffer], ADMIN_SUPPORT))
					{
						g_szSettings[iAdminSupport] = str_to_num(szTemp[szValue])
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

	if(g_szSettings[iAdminSupport])
	{
		/* Flush data got from configuration file */
		ArrayClear(g_aReservedSlot)

		if(g_szSettings[iAdminSupport] == 2)
		{
			server_cmd("amx_reloadadmins") 
			server_exec()
		}

		new iSize = admins_num(), iFlags, iAccess

		for(new i; i < iSize; i++)
		{
			iFlags = admins_lookup(i, AdminProp_Flags)

			iAccess = admins_lookup(i, AdminProp_Access)

			/* Can't retrieve steamid from SV_ConnectClient Hook, just skip who has steamid as admin auth. 
				If admin's access is not the same as the immunity flag, just skip him. */
			if(iFlags & FLAG_AUTHID || !(iAccess & read_flags(g_szSettings[szImmunityFlag])))
				continue

			if(iFlags & FLAG_KICK)
			{
				set_player_data(AdminProp_Password, szTemp[szValue], charsmax(szTemp[szValue]), i, iFlags, szTemp[szBuffer], charsmax(szTemp[szBuffer]))
			}
			else
			{
				set_player_data(AdminProp_Auth, szTemp[szValue], charsmax(szTemp[szValue]), i, iFlags, szTemp[szBuffer], charsmax(szTemp[szBuffer]))
			}

			ArrayPushArray(g_aReservedSlot, szTemp)
		}
	}

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

public SV_ConnectClient_Pre()
{
	new iPNum = get_playersnum_ex(GetPlayers_IncludeConnecting)

	/* Set max visible player slots if VGUI Support is enabled */
	set_visible_players(iPNum) 

	/* If connected players num is lower than 32, stop the function */
	if(iPNum != g_iMaxPlayers)
		return

	new szPlayerData[Enum_PData], eArray[Enum_Data], bool:bFound, szTemp[MAX_INFO_STRING] 
	
	/* Retrieving connecting player's IP address also his name to check them later... */
	rh_get_net_from(szPlayerData[szIP], charsmax(szPlayerData[szIP]))

	/* Fourth agrument is always userinfo */
	read_argv(4, szTemp, charsmax(szTemp))

	new iPosName = containi(szTemp, name_field), iPosPassword = containi(szTemp, g_szSettings[szPassField])

	if(iPosName != -1)
	{
		/* iPosName shows the position in the userinfo for name and adding 5 will skip 5 characters  : "name\" */
		copyc(szPlayerData[szName], charsmax(szPlayerData[szName]), szTemp[iPosName + 5], '\')
	}

	if(iPosPassword != -1)
	{
		/* iPosPassword shows the position in the userinfo for password and adding strlen() of g_szSettings[szPassField] */
		copyc(szPlayerData[szPassword], charsmax(szPlayerData[szPassword]), szTemp[iPosPassword + strlen(g_szSettings[szPassField]) + 1], '\')
	}
	new iSize = ArraySize(g_aReservedSlot)

	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aReservedSlot, i, eArray, charsmax(eArray))

		if(is_player_reserved(szPlayerData, eArray))
		{
			bFound = true
			break
		}
	}

	if(bFound)
	{
		new iPlayers[MAX_PLAYERS], iSelected[MAX_PLAYERS], iNum, iPlayer, iCount, bool:bInclude[2]
		get_players_filtered(iPlayers, iNum)

		bInclude[0] = g_szSettings[bIncludeAdmins]
		bInclude[1] = g_szSettings[bIncludeBots]

		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[i]

			if(!bInclude[0] && has_flag(iPlayer, g_szSettings[szImmunityFlag]) || !bInclude[1] && is_user_bot_hltv(iPlayer))
				continue

			iSelected[iCount] = iPlayer
			iCount++
		}

		new iRandomPlayer = -1, bool:bChecked

		switch(g_szSettings[iKickByPlayedTime])
		{
			case iMostPlayedTime, iLesserPlayedTime:
			{
				bChecked = true
				iRandomPlayer = get_player_by_playtime(iSelected, iCount, g_szSettings[iKickByPlayedTime])
			}
		}

		if(iRandomPlayer == -1)
		{
			get_random_player(iRandomPlayer, iCount - 1)
		}

		if(!is_user_connected(bChecked ? iRandomPlayer : iSelected[iRandomPlayer]))
			return

		rh_drop_client(bChecked ? iRandomPlayer : iSelected[iRandomPlayer], g_szSettings[szKickMessage])
	}
}

bool:is_user_bot_hltv(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return true 

	return false
}

bool:get_players_filtered(iPlayers[MAX_PLAYERS], &iNum)
{
	new bool:bCustomFilter

	if(g_szSettings[bKickSpectator])
		bCustomFilter = true

	recount:
	get_players(iPlayers, iNum, bCustomFilter ? "e" : "", bCustomFilter ? "SPECTATOR" : "")

	if(!iNum && g_szSettings[bKickSpectator])
	{
		bCustomFilter = false
		goto recount
	}

	return true
}

get_random_player(&iNum, iCount)
{
	iNum = iCount > 1 ? random_num(1, iCount) : 0
}

get_player_by_playtime(iPlayers[MAX_PLAYERS], iCount, iCriteria)
{
	if(!iCount)	
		return -1

	new iTempID
	SortCustom1D(iPlayers, iCount, "compare_playtime")

	switch(iCriteria)
	{
		case iMostPlayedTime:
		{
			iTempID = iPlayers[0]
		}
		case iLesserPlayedTime:
		{
			iTempID = iPlayers[iCount - 1]
		}
	}

	return iTempID
}

public compare_playtime(iPlayer1, iPlayer2)
{
	new iPTime[2]
	iPTime[0] = get_user_time(iPlayer1, 1)
	iPTime[1] = get_user_time(iPlayer2, 1)

	if(iPTime[0] > iPTime[1])
		return -1
	else if(iPTime[0] < iPTime[1])
		return 1

	return 0
}

bool:is_player_reserved(szPData[Enum_PData], szArray[Enum_Data])
{
	/* Searching for player's reserved data in array. If found, then the function can begin it's verification proccess */
	switch(szArray[szValue][0])
	{
		case 'N':
		{
			if(equali(szPData[szName], szArray[szBuffer], charsmax(szPData[szName])))
			{
				return true
			}
		}
		case 'P':
		{
			if(equali(szPData[szPassword], szArray[szBuffer], charsmax(szPData[szPassword])))
			{
				return true
			}
		}
		case 'I':
		{
			if(equali(szPData[szIP], szArray[szBuffer], charsmax(szPData[szIP])))
			{
				return true
			}
		}
	}

	return false
}

set_player_data(AdminProp:iAuthProp, szTemp[], iTempLen, iNum, iFlags, szAuth[], iAuthLen)
{
	if(iFlags & FLAG_KICK)
	{
		formatex(szTemp, iTempLen, "Password")
	}
	else if(iFlags & (FLAG_NOPASS | FLAG_TAG | FLAG_CASE_SENSITIVE))
	{
		formatex(szTemp, iTempLen, "Name")
	}
	else if(iFlags & FLAG_IP)
	{
		formatex(szTemp, iTempLen, "IP")
	}

	admins_lookup(iNum, iAuthProp, szAuth, iAuthLen)
}

set_visible_players(iNum)
{
	set_pcvar_num(g_iPointer, iNum >= g_iMaxPlayers - 1 && g_szSettings[bVGUISupport] ? g_iMaxPlayers + 1 /* We just need one more slot */ : g_iMaxPlayers)
}