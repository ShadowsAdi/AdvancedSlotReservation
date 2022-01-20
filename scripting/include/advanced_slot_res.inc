/* Sublime AMXX Editor v4.2 */

#if defined _adv_slot_reservation_included
	#endinput
#endif
#define _adv_slot_reservation_included

#if !defined MAX_NAME_LENGTH 
#define MAX_NAME_LENGTH 32
#endif

#if !defined MAX_IP_LENGTH
#define MAX_IP_LENGTH 16
#endif

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

/* Engine const https://github.com/dreamstalker/rehlds/blob/master/rehlds/engine/info.h#L37 */
#define MAX_INFO_STRING 256

#define MAX_STRING 256

#define MAX_USER_INFO_PASSWORD 32

/* Custom return values */
enum (+=250)
{
	SLOT_KICK_NO = 0,
	SLOT_KICK_YES
};

enum _:PlayerData
{
	szIP[MAX_IP_LENGTH],
	szName[MAX_NAME_LENGTH],
	szPassword[MAX_USER_INFO_PASSWORD]
};

/**
 * @description				Multiforward called before a player will be kicked to free a player slot.
 *
 * @param id				Choosen player to be kicked index.
 * @param szPlayerData		Array which contains data of the reserved client.
 * 
 * @return					Return SLOT_KICK_YES if you want to not let the plugin kick the player or SLOT_KICK_NO to continue executing.
 */
forward player_kick_pre(id, szPlayerData[PlayerData]);

/**
 * @description				Multiforward called right before a player will be kicked to free a player slot.
 *
 * @param id				Choosen player to be kicked index.
 * @param szPlayerData		Array which contains data of the reserved client.
 * 
 * @return					Forward ignores return values.
 */
forward player_kick_post(id, szPlayerData[PlayerData]);

/**
 * @description				Multiforward called after the player array was sorted.
 *
 * @param szPlayers			Array which contains player's indexes.
 * @param iTotalPlayers		Total of players included in the sorting algorithm.
 * 
 * @note					Array will be passed in kicking function with the changes made inside this forward.
 * 
 * @return					Forward ignores return values.
 */
forward player_check_playtime(szPlayers[MAX_PLAYERS], iTotalPlayers);

/* Support for AmxModX versions lower that 1.8.3 */
#if AMXX_VERSION_NUM < 183
enum GetPlayersFlags (<<= 1)
{
    GetPlayers_None = 0,           // No filter (Default)
    GetPlayers_ExcludeDead = 1,    // Do not include dead clients
    GetPlayers_ExcludeAlive,       // Do not include alive clients
    GetPlayers_ExcludeBots,        // Do not include bots
    GetPlayers_ExcludeHuman,       // Do not include human clients
    GetPlayers_MatchTeam,          // Match with team
    GetPlayers_MatchNameSubstring, // Match with part of name
    GetPlayers_CaseInsensitive,    // Match case insensitive
    GetPlayers_ExcludeHLTV,        // Do not include HLTV proxies
    GetPlayers_IncludeConnecting   // Include connecting clients
};

stock get_players_ex(players[MAX_PLAYERS] = {}, &num, GetPlayersFlags:flags = GetPlayers_None, const team[] = "")
{
    new strFlags[10];
    get_flags(_:flags, strFlags, charsmax(strFlags));
    get_players(players, num, strFlags, team);
}

stock get_playersnum_ex(GetPlayersFlags:flags = GetPlayers_None, const team[] = "")
{
    new PlayersNum;
    get_players_ex(_, PlayersNum, flags, team);
    return PlayersNum;
}
#endif