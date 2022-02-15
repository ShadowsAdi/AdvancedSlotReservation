/* Sublime AMXX Editor v4.2 */

/* 	Uncomment this line to use reAPI Support.
	NOTE! Only reAPI can use reservation of the IP address! 
*/
//#define USE_REAPI

#include <amxmodx>
#include <amxmisc>
#if defined USE_REAPI
#include <reapi>
#else
#include <orpheu>
#endif
#include <advanced_slot_res>

#define PLUGIN  "[Advanced Slot Reservation]"
#define VERSION "2.2"
#define AUTHOR  "Shadows Adi"

new const name_field[]           =          "name"

new const INCLUDE_ADMINS[]       =          "INCLUDE_ADMINS"
new const INCLUDE_BOTS[]         =          "INCLUDE_BOTS"
new const KICK_SPECTATOR[]       =          "KICK_SPECTATOR"
new const KICK_PLAYER_BY_PTIME[] =          "KICK_PLAYER_BY_PLAYTIME"
new const RELOAD_FILE[]          =          "RELOAD_FILE_ACCESS"
new const ADMIN_IMMUNITY_FLAG[]  =          "ADMIN_IMMUNITY_FLAG"
new const KICK_MESSAGE[]         =          "KICK_MESSAGE"
new const USER_PASS_FIELD[]      =          "USERINFO_PASSWORD_FIELD"
new const VGUI_SUPPORT[]         =          "VGUI_SUPPORT"
new const ADMIN_SUPPORT[]        =          "ADMIN_SUPPORT"
new const HASHING_SUPPORT[]      =          "HASHING_SUPPORT"

enum _:Enum_Data
{
	szBuffer[MAX_NAME_LENGTH + 1],
	szValue[MAX_STRING]
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

enum _:Enum_Forwards
{
	PlayerKickPre,
	PlayerKickPost,
	PlayerCheckPlayTime
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
	iAdminSupport,
	iHashSupport
}

new Array:g_aReservedSlot
new g_iMaxPlayers
new g_szSettings[Enum_Settings]
new g_iPointer

new g_iForwards[Enum_Forwards], g_iForwardRet

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("adv_slot_reservation", AUTHOR, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)

	#if defined USE_REAPI

	if(!is_rehlds())
	{
		set_fail_state("ReHLDS API Not Found!")
	}

	RegisterHookChain(RH_SV_ConnectClient, "SV_ConnectClient_Pre", 0)

	g_iMaxPlayers = get_member_game(m_nMaxPlayers)
	#else

	OrpheuRegisterHook(OrpheuGetFunction("SV_ConnectClient"), "SV_ConnectClient_Pre", OrpheuHookPre)

	g_iMaxPlayers = get_maxplayers()
	#endif

	g_aReservedSlot = ArrayCreate(Enum_Data)

	g_iForwards[PlayerKickPre] = CreateMultiForward("player_kick_pre", ET_STOP, FP_CELL, FP_ARRAY)
	g_iForwards[PlayerKickPost] = CreateMultiForward("player_kick_post", ET_IGNORE, FP_CELL, FP_ARRAY)
	g_iForwards[PlayerCheckPlayTime] = CreateMultiForward("player_check_playtime", ET_STOP, FP_ARRAY, FP_CELL)

	/* Setting this cvar to let the player trigger SV_ConnectClient() function, followed by SV_ConnectClient_internal() function, finally checking if there is
	any free player slot in SV_FindEmptySlot() function

		SV_ConnectClient:				https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2261-L2264
		SV_ConnectClient_internal : 	https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2266
		SV_FindEmptySlot call: 			https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2385-L2387
		SV_FindEmptySlot function: 		https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/sv_main.cpp#L2236-L2259 
	*/

	g_iPointer = get_cvar_pointer("sv_visiblemaxplayers")
}

public plugin_natives()
{
	register_library("adv_slot_reservation")
}

public plugin_cfg()
{
	/* This should fix dynamic admin storage support for SQL versions, if your dynamic admins are not loaded, reload the file using the command. */
	set_task(1.0, "task_delayed_plugin_cfg")
}

public task_delayed_plugin_cfg()
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

	if(!iFile)
		return 0

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
				else if(equali(szTemp[szBuffer], HASHING_SUPPORT))
				{
					g_szSettings[iHashSupport] = clamp(str_to_num(szTemp[szValue]), -1, 11)
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
	fclose(iFile)

	if(g_szSettings[iAdminSupport])
	{
		if(g_szSettings[iAdminSupport] >= 2)
		{
			server_cmd("amx_reloadadmins") 
			server_exec()

			if(g_szSettings[iAdminSupport] != 3)
			{
				/* Delete data got from configuration file */
				ArrayClear(g_aReservedSlot)
			}
		}

		new iSize = admins_num(), iFlags, iAccess

		for(new i; i < iSize; i++)
		{
			iFlags = admins_lookup(i, AdminProp_Flags)

			iAccess = admins_lookup(i, AdminProp_Access)

			/* Can't retrieve steamid from SV_ConnectClient Hook, just skip who has steamid as admin auth. 
				If admin's access is not the same as the immunity flag, just skip him. */
			#if defined USE_REAPI
			if(iFlags & FLAG_AUTHID || !(iAccess & read_flags(g_szSettings[szImmunityFlag])))
			#else
			if(iFlags & FLAG_AUTHID || iFlags & FLAG_IP || !(iAccess & read_flags(g_szSettings[szImmunityFlag])))
			#endif
				continue

			set_player_data((iFlags & FLAG_KICK) ? AdminProp_Password : AdminProp_Auth, szTemp[szValue], charsmax(szTemp[szValue]), i, iFlags, szTemp[szBuffer], charsmax(szTemp[szBuffer]))

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

	new szPlayerData[PlayerData], eArray[Enum_Data], bool:bFound, szTemp[MAX_INFO_STRING] 

	#if defined USE_REAPI
	/* Retrieving connecting player's IP address also his name to check them later... */
	rh_get_net_from(szPlayerData[szIP], charsmax(szPlayerData[szIP]))

	new iPos = contain(szPlayerData[szIP], ":")

	if(iPos != -1) 
	{
		szPlayerData[szIP][iPos] = EOS
	}
	#endif

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
		#if AMXX_VERSION_NUM < 183
		ArrayGetArray(g_aReservedSlot, i, eArray)
		#else
		ArrayGetArray(g_aReservedSlot, i, eArray, charsmax(eArray))
		#endif

		if(is_player_reserved(szPlayerData, eArray))
		{
			bFound = true
			break
		}
	}

	if(bFound)
	{
		new iSelected[MAX_PLAYERS], iCount

		if(!get_players_filtered(iSelected, iCount))
		{
			log_to_file("advanced_slot_reservation.log", "Something strange just happened, couldn't sort the players list!")
			return
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

		if(iRandomPlayer <= 0)
		{
			bChecked = false
			get_random_player(iRandomPlayer, iCount - 1)		
		}

		new hArray = PrepareArray(szPlayerData, sizeof(szPlayerData))
		new iTempID = bChecked ? iRandomPlayer : iSelected[iRandomPlayer]

		ExecuteForward(g_iForwards[PlayerKickPre], g_iForwardRet, iTempID, hArray)

		if(g_iForwardRet >= SLOT_KICK_YES)
			return

		ExecuteForward(g_iForwards[PlayerKickPost], g_iForwardRet, iTempID, hArray)

		#if defined USE_REAPI
		rh_drop_client(iTempID, g_szSettings[szKickMessage])
		#else
		server_cmd("kick #%d ^"%s^"", get_user_userid(iTempID), g_szSettings[szKickMessage])
		#endif
	}
}

bool:is_user_bot_hltv(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return true 

	return false
}

bool:get_players_filtered(iPlayerArray[MAX_PLAYERS], &iNum)
{
	new bool:bCustomFilter, iIterator, bool:bInclude[2], iPlayer, iPlayers[MAX_PLAYERS]

	if(g_szSettings[bKickSpectator])
		bCustomFilter = true

	bInclude[0] = g_szSettings[bIncludeAdmins]
	bInclude[1] = g_szSettings[bIncludeBots]

	recount:
	get_players(iPlayers, iIterator, bCustomFilter ? "e" : "", bCustomFilter ? "SPECTATOR" : "")

	for(new i; i < iIterator; i++)
	{
		iPlayer = iPlayers[i]

		if(!bInclude[0] && has_flag(iPlayer, g_szSettings[szImmunityFlag]) || !bInclude[1] && is_user_bot_hltv(iPlayer) || !is_user_connected(iPlayer))
			continue

		iPlayerArray[iNum] = iPlayer
		iNum++
	}

	if(!iNum)
	{
		if(g_szSettings[bKickSpectator])
		{
			bCustomFilter = false
			goto recount
		}
		return false
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

	ExecuteForward(g_iForwards[PlayerCheckPlayTime], g_iForwardRet, PrepareArray(iPlayers, sizeof(iPlayers), 1), iCount)

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

bool:is_player_reserved(szPData[PlayerData], szArray[Enum_Data])
{
	/* Searching for player's reserved data in array. If found, then the function can begin it's verification proccess */
	switch(szArray[szValue][0])
	{
		case 'N':
		{
			if(equali(szPData[szName], szArray[szBuffer], strlen(szPData[szName])))
			{
				return true
			}
		}
		case 'P':
		{
			static sTemp[34]
			copy(sTemp, charsmax(sTemp), szPData[szPassword])
			if(g_szSettings[iHashSupport] >= 0 && (0 < g_szSettings[iAdminSupport] < 3))
			{
				#if AMXX_VERSION_NUM < 183
				md5(szPData[szPassword], sTemp)
				#else
				hash_string(szPData[szPassword], HashType:g_szSettings[iHashSupport], sTemp, charsmax(sTemp))
				#endif
			}
			
			if(equali(sTemp, szArray[szBuffer], strlen(sTemp)))
			{
				return true
			}
		}
		#if defined USE_REAPI
		case 'I':
		{
			if(equali(szPData[szIP], szArray[szBuffer], strlen(szPData[szIP])))
			{
				return true
			}
		}
		#endif
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
	#if defined USE_REAPI
	else if(iFlags & FLAG_IP)
	{
		formatex(szTemp, iTempLen, "IP")
	}
	#endif

	admins_lookup(iNum, iAuthProp, szAuth, iAuthLen)
}

set_visible_players(iNum)
{
	set_pcvar_num(g_iPointer, iNum >= g_iMaxPlayers - 1 && g_szSettings[bVGUISupport] ? g_iMaxPlayers + 1 /* We just need one more slot */ : g_iMaxPlayers)
}