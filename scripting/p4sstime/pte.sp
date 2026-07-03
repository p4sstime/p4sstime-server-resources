// passtime_extras plugin by xCape
// used here as reference to carry over diff features over to the main plugin.

// Imports
#include <clientprefs>
#include <clients>
#include <sdkhooks>
#include <sdktools_entoutput>
#include <sdktools_functions>
#include <sdktools_gamerules>
#include <sdktools_trace>
#include <sdktools>
#include <sourcemod>
#include <tf2_stocks>
#include <tf2>
#include <tf2attributes>
#include "include/morecolors.inc"

#pragma semicolon 1

// Constants
#define RED         0
#define BLU         1
#define TEAM_OFFSET 2
#define EDICT       2048
#define MAXSPAWNS   4
#define MAXSLOTS    2
#define RESUPDIST   512.0    // Max dist from spawn resupply can be used

// Simple
#define len         sizeof
#define as          view_as
#define Reply       ReplyToCommand
#define elif        else if

#define AC          CAddColor
#define CC          RegConsoleCmd
#define CCS         RegConsoleCmdWithShort
#define RA          RegAdminCmd
#define ACS         RegAdminCmdWithShort

#define NOTIFY      FCVAR_NOTIFY
#define GENERIC     ADMFLAG_GENERIC

// Complex macros
#define GET_ARG(%1,%2,%3) \
    char %2 [%3];            \
    GetCmdArg(%1,%2,%3)
#define NEW_CMD(%1)           public Action %1( int client, int args )
#define NEW_EV_ACT(%1)        public Action %1( Event event, const char[] name, bool dontBroadcast )
#define NEW_EV(%1)            public %1( Event event, const char[] name, bool dontBroadcast )
#define STRCP(%1,%2)          strcopy(%1, len(%1),%2)
#define FOR_EACH_CLIENT(%1)   for (int %1 = 1;%1 <= MaxClients;%1 ++)
#define FOR_EACH_ENT(%1)      for (int %1 = 1;%1 <= EDICT;%1 ++)
#define END_CMD(%1)           return EndCommand( client,%1)
#define END_CMD2(%1,%2)       return EndCommand(%1,%2)
#define END_CMD3(%1,%2,%3)    return EndCommand(%1,%2,%3)
#define END_CMD4(%1,%2,%3,%4) EndCommand(%1,%2,%3,%4)

public Plugin myinfo =
{
    name        = "passtime.tf extras",
    author      = "xCape",
    description = "Plugin for use in passtime.tf servers",
    version     = "1.9.0",
    url         = "https://github.com/allvei/passtime-extras/" 
}

// Handles
Handle    g_hCookieFOV;
Handle    g_hCookieInfiniteAmmo;
Handle    g_hCookieImmunity;

// ConVars
ConVar    g_cvFovMin;
ConVar    g_cvFovMax;

// Demoman boots attribute ConVars
ConVar    g_cvBootsChargeTurn;
ConVar    g_cvBootsMaxHealth;
ConVar    g_cvBootsKillRefill;
ConVar    g_cvBootsMoveSpeed;

// Backup system for FOV tracking when Steam connection is down
bool      g_bSteamOnline = true;             // Track if Steam is currently connected
bool      g_bBackupFOVDB = false;            // Track if we're using the backup system
bool      g_bPlayerTracked[ MAXPLAYERS ];    // Track if we have a FOV value for this player
int       g_iPlayerFOV[ MAXPLAYERS ];        // Store FOV values for each player

// Backup system for infinite ammo and immunity when Steam is down
bool      g_bBackupInfiniteAmmoTracked[ MAXPLAYERS ];    // Track if we have infinite ammo setting for this player
bool      g_bBackupImmunityTracked[ MAXPLAYERS ];        // Track if we have immunity setting for this player
bool      g_bBackupInfiniteAmmo[ MAXPLAYERS ];           // Store infinite ammo setting for each player
bool      g_bBackupImmunity[ MAXPLAYERS ];               // Store immunity setting for each player

// Resupply tracking
bool      g_bResupplyDn[ MAXPLAYERS ];    // Is resupply key down
bool      g_bResupplyUp[ MAXPLAYERS ];    // Has resupply been used during current key press

// Immunity & infinite ammo toggle per player
bool      g_bImmunity[ MAXPLAYERS ];
int       g_iPreDamageHP[ MAXPLAYERS ];
bool      g_bPendingHP[ MAXPLAYERS ];
bool      g_bInfiniteAmmo[ MAXPLAYERS ];

// Respawn time control
ConVar    g_cvRespawnTime;
bool      g_bIsTeamReady[ 2 ] = { false, false };    // Track ready state for RED and BLU

// Saved spawn point (admin tools)
bool      g_bSavedSpawnValid  = false;
float     g_vSavePos[ 3 ];
float     g_vSaveAng[ 3 ];
float     g_vSaveVel[ 3 ];

// Backup tournament controls
bool      g_bResupplyEnabled             = true;
bool      g_bInstantRespawnEnabled       = true;
bool      g_bImmunityAmmoEnabled         = true;
bool      g_bSaveEnabled                 = true;
bool      g_bDemoResistEnabled           = false;

// Performance optimization: cached entity indices
int       g_iCachedTimerEntity           = -1;
ArrayList g_hCachedSpawnRooms            = null;
ArrayList g_hCachedSpawnPoints[ 2 ]      = { null, null };    // RED and BLU spawn points

// Mirror spawnpoint system
ArrayList g_hMirrorSpawnPoints[ 2 ][ 2 ] = {
    {null,  null},
    { null, null}
};                          // [team][side] where team=0=RED,1=BLU and side=0=left,1=right
float g_fMirrorPlaneX                = 0.0;    // X coordinate of the middle plane
float g_fMirrorPlaneY                = 0.0;    // Y coordinate of the middle plane
bool  g_bMirrorSystemOn     = false;

// Round state tracking
int   g_iCurrentRoundState           = 0;
bool  g_bPrintRoundStateUpdates      = false;

// Sequential spawnpoint tracking
int   g_iCurrentSpawnIndex[ 2 ][ 2 ] = {
    {0,  0},
    { 0, 0}
};    // [team][side] current spawnpoint index

// Performance optimization: demo resistance state tracking
float g_fCurrentDemoResistValue[ MAXPLAYERS ];    // Track current applied resistance value
bool  g_bDemoResistApplied[ MAXPLAYERS ];         // Track if resistance is currently applied

// Demoman boots attribute tracking
float g_fCurrentBootsChargeTurn[ MAXPLAYERS ];
float g_fCurrentBootsMaxHealth[ MAXPLAYERS ];
float g_fCurrentBootsKillRefill[ MAXPLAYERS ];
float g_fCurrentBootsMoveSpeed[ MAXPLAYERS ];
bool  g_bBootsAttributesApplied[ MAXPLAYERS ];

// Performance optimization: static ammo arrays (replace ArrayList allocations)
int   g_iStaticOriginalAmmo[ MAXPLAYERS ][ 34 ];    // 2 clip values + 32 ammo types
bool  g_bStaticAmmoValid[ MAXPLAYERS ];             // Track if ammo data is valid

int   g_iSavedClip1[ MAXSLOTS ];
int   g_iSavedClip2[ MAXSLOTS ];
int   g_iSavedAmmoType[ MAXSLOTS ][ 2 ];
int   g_iSavedAmmoCount[ MAXSLOTS ][ 2 ];

public OnPluginStart() {
    // Admin commands
    ACS( "sm_force_ready",       "sm_fr",   CForceReady,       GENERIC, "Set a team's ready status" );
    ACS( "sm_debug_roundtime",   "sm_drt",  CDebugRoundTime,   GENERIC, "Debug: print team_round_timer info" );
    ACS( "sm_enable_resupply",   "sm_res",  CToggleResupply,   GENERIC, "Toggle resupply functionality" );
    ACS( "sm_enable_respawn",    "sm_resp", CToggleRespawn,    GENERIC, "Toggle instant respawn" );
    ACS( "sm_enable_immunity",   "sm_imm",  CToggleImmunity,   GENERIC, "Toggle immunity and infinite ammo" );
    ACS( "sm_enable_saveload",   "sm_sl",   CToggleSave,       GENERIC, "Toggle save/load spawn functionality" );
    ACS( "sm_enable_demoresist", "sm_dr",   CToggleDemoResist, GENERIC, "Toggle demo blast vulnerability" );
    ACS( "sm_list_blast_attrib", "sm_lba",  CListBlastAttrib,  GENERIC, "Debug: list entities with blast attributes" );
    ACS( "sm_add_tag",           "sm_atag", CAddTag,           GENERIC, "Add prefix tag to all players on a team" );
    ACS( "sm_remove_tag",        "sm_rtag", CRemoveTag,        GENERIC, "Remove prefix tag from all players on a team" );
    ACS( "sm_get_round_state",   "sm_grs",  CGetRoundState,    GENERIC, "Get current round state" );

    // Runner commands
    ACS( "sm_setteam",  "sm_st", CSetTeam,  GENERIC, "Set a client's team" );
    ACS( "sm_setclass", "sm_sc", CSetClass, GENERIC, "Set a client's class" );

    // Console commands
    CCS( "sm_save",                     "sm_sv",   CSaveSpawn,             "Save a spawn point" );
    CCS( "sm_load",                     "sm_ld",   CLoadSpawn,             "Teleport to saved spawn" );
    CCS( "sm_immune",                   "sm_i",    CImmune,                "Toggle immunity" );
    CCS( "sm_ammo",                     "sm_a",    CInfAmmo,               "Toggle infinite ammo" );
    CCS( "sm_diceroll",                 "sm_dice", CDice,                  "Select a random player from targets" );
    CCS( "sm_ready",                    "sm_r",    CReady,                 "Toggle your team's ready state" );
    CCS( "sm_team_name",                "sm_tn",   CTeamName,              "Rename your team" );
    CC(  "sm_fov",                                 CSetFOV,                "Set your field of view." );
    CC(  "+sm_resupply",                           CResupDn,               "Resupply inside spawn" );
    CC(  "-sm_resupply",                           CResupUp,               "Resupply inside spawn" );
    CC(  "+sm_pt_resupply",                        CResupDn,               "Resupply inside spawn" );
    CC(  "-sm_pt_resupply",                        CResupUp,               "Resupply inside spawn" );
    CCS( "sm_print_round_state_update", "sm_prsu", CPrintRoundStateUpdate, "Print round state changes to chat" );

    CAddColor( "steamlightgreen", 0x9DC250 );    // #9dc250ff
    CAddColor( "teamblu", 0x99CCFF );            // #99ccffff
    CAddColor( "teamred", 0xFF3F35 );            // #ff3f35ff

    g_hCookieFOV          = RegClientCookie( "sm_fov_cookie", "Desired client field of view", CookieAccess_Private );
    g_hCookieInfiniteAmmo = RegClientCookie( "sm_infiniteammo_cookie", "Infinite ammo setting", CookieAccess_Private );
    g_hCookieImmunity     = RegClientCookie( "sm_immunity_cookie", "Immunity setting", CookieAccess_Private );

    // Console variables
    g_cvFovMin            = CreateConVar( "sm_fov_min",      "70",  "Minimum client field of view", _, 1, 1.0, 1, 175.0 );
    g_cvFovMax            = CreateConVar( "sm_fov_max",      "120", "Maximum client field of view", _, 1, 1.0, 1, 175.0 );
    g_cvRespawnTime       = CreateConVar( "sm_respawn_time", "0.0", "Player respawn delay in seconds", NOTIFY );

    // Demoman boots attribute ConVars
    g_cvBootsChargeTurn   = CreateConVar( "sm_boots_charge_turn", "3.0",  "Charge turn control multiplier for Demoman boots",     NOTIFY );
    g_cvBootsMaxHealth    = CreateConVar( "sm_boots_max_health",  "25.0", "Max health additive bonus for Demoman boots",          NOTIFY );
    g_cvBootsKillRefill   = CreateConVar( "sm_boots_kill_refill", "0.25", "Kill refills meter value for Demoman boots",           NOTIFY );
    g_cvBootsMoveSpeed    = CreateConVar( "sm_boots_move_speed",  "1.10", "Move speed bonus (shield required) for Demoman boots", NOTIFY );

    // Hook events
    HookEvent( "player_spawn",               EPSpawn );
    HookEvent( "player_disconnect",          EPDisconnect );
    HookEvent( "player_death",               EPDeath );
    HookEvent( "post_inventory_application", EPInventoryApplication );
    HookEvent( "teamplay_round_start",       EPRoundStart );
    HookEvent( "teamplay_round_active",      EPRoundActive );
    HookEvent( "teamplay_restart_round",     EPRoundRestart );
    HookEvent( "teamplay_round_win",         EPRoundWin );
    HookEvent( "teamplay_game_over",         EPRoundGameOver );

    // Initialize team ready states
    g_bIsTeamReady[ 0 ] = false;
    g_bIsTeamReady[ 1 ] = false;

    // Initialize spawn room tracking arrays
    FOR_EACH_CLIENT( n ) {
        g_bResupplyDn[ n ] = false;
        g_bResupplyUp[ n ] = false;
    }

    // Initialize saved ammo/velocity buffers
    for ( int s = 0; s < MAXSLOTS; s++ ) {
        g_iSavedClip1[ s ] = -1;
        g_iSavedClip2[ s ] = -1;
        for ( int t = 0; t < 2; t++ ) {
            g_iSavedAmmoType[ s ][ t ]  = -1;
            g_iSavedAmmoCount[ s ][ t ] = 0;
        }
    }

    // Initialize infinite ammo and backup tracking
    FOR_EACH_CLIENT( n ) {
        g_bInfiniteAmmo[ n ]              = false;
        g_bBackupInfiniteAmmoTracked[ n ] = false;
        g_bBackupImmunityTracked[ n ]     = false;
        g_bBackupInfiniteAmmo[ n ]        = false;
        g_bBackupImmunity[ n ]            = false;

        // Initialize performance optimization arrays
        g_fCurrentDemoResistValue[ n ]    = 0.0;
        g_bDemoResistApplied[ n ]         = false;
        g_bStaticAmmoValid[ n ]           = false;

        // Initialize static ammo array
        for ( int j = 0; j < 34; j++ ) {
            g_iStaticOriginalAmmo[ n ][ j ] = 0;
        }
    }

    // Hook damage for currently connected clients and reset nodamage flags
    FOR_EACH_CLIENT( n ) {
        g_bImmunity[ n ]    = false;
        g_bPendingHP[ n ]   = false;
        g_iPreDamageHP[ n ] = 0;
        if ( IsClientInGame( n ) ) {
            SDKHook( n, SDKHook_OnTakeDamage, Hook_OnTakeDamage );
            SDKHook( n, SDKHook_OnTakeDamagePost, Hook_OnTakeDamagePost );

            // Load cookies for currently connected clients on plugin load/reload
            LoadClientCookies( n );
        }
    }

    // Initialize entity cache arrays
    g_hCachedSpawnRooms              = new ArrayList();
    g_hCachedSpawnPoints[ RED ]      = new ArrayList();
    g_hCachedSpawnPoints[ BLU ]      = new ArrayList();

    // Initialize mirror spawnpoint arrays
    g_hMirrorSpawnPoints[ RED ][ 0 ] = new ArrayList();    // RED left
    g_hMirrorSpawnPoints[ RED ][ 1 ] = new ArrayList();    // RED right
    g_hMirrorSpawnPoints[ BLU ][ 0 ] = new ArrayList();    // BLU left
    g_hMirrorSpawnPoints[ BLU ][ 1 ] = new ArrayList();    // BLU right

    // Build initial entity cache
    BuildEntityCache();
}

// Load infinite ammo and immunity cookies for a client on plugin load/reload
void LoadClientCookies( int client ) {
    if ( !IsValidClient( client ) ) return;

    // Only load cookies if they are cached (Steam is online)
    if ( AreClientCookiesCached( client ) ) {
        // Only load ammo cookie if player is alive and has a weapon
        // This prevents ArrayList errors during plugin startup
        if ( IsPlayerAlive( client ) ) {
            int weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
            if ( weapon != -1 && IsValidEntity( weapon ) ) {
                GetAmmoCookie( client );
            }
        }

        // Immunity and FOV cookies don't require weapons, so they're safe to load
        GetImmunityCookie( client );
        GetFOVCookie( client );
    }
}

// OnGameFrame() with immediate response for resupply and ammo
public void OnGameFrame() {
    // Only validate entity cache periodically (every 30 frames = ~0.5 seconds)
    static int frameCounter = 0;
    if ( ++frameCounter >= 30 ) {
        frameCounter = 0;
        ValidateEntityCache();
    }

    FOR_EACH_CLIENT( client ) {
        if ( !IsValidClientAlive( client ) ) continue;

        // Handle infinite ammo excluding medics
        if ( !IsMatch() && g_bImmunityAmmoEnabled && g_bInfiniteAmmo[ client ] && TF2_GetPlayerClass( client ) != TFClass_Medic ) {
            // Get the active weapon
            int weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
            if ( weapon != -1 && IsValidEntity( weapon ) ) {
                SetEntProp( weapon, Prop_Send, "m_iClip1", 19 );
                SetAmmo( client, weapon, 84 );
            }
        }

        // Check for buffered resupply (only if globally enabled)
        if ( g_bResupplyEnabled && g_bResupplyDn[ client ] && !g_bResupplyUp[ client ] && IsClientInSpawnroom( client ) ) {
            Resupply( client );
        }
    }

    // Only demo resistance moved to event-driven hooks (applied on spawn/class change)
}

// Hook per-client when they enter the server so our damage filter is active
public void OnClientPutInServer( int client ) {
    SDKHook( client, SDKHook_OnTakeDamage, Hook_OnTakeDamage );
    SDKHook( client, SDKHook_OnTakeDamagePost, Hook_OnTakeDamagePost );

    // Initialize performance tracking for this client
    g_fCurrentDemoResistValue[ client ] = 0.0;
    g_bDemoResistApplied[ client ]      = false;
    g_bStaticAmmoValid[ client ]        = false;

    if ( g_bBackupFOVDB ) {
        // Reset tracking for this player slot if backup system is active
        g_bPlayerTracked[ client ] = false;
        g_iPlayerFOV[ client ]     = 0;
    }
}

// Use cached timer entity
bool IsMatch() {
    // Match is not active if game is awaiting ready restart, timer is paused, or timer is disabled
    bool awaitingReadyRestart = as<bool>( GameRules_GetProp( "m_bAwaitingReadyRestart" ) );
    bool timerPaused          = false;
    bool timerDisabled        = false;
    bool IsPostRound          = GameRules_GetRoundState() == RoundState_TeamWin;

    // Use cached timer entity instead of searching
    if ( g_iCachedTimerEntity != -1 && IsValidEntity( g_iCachedTimerEntity ) ) {
        timerPaused   = as<bool>( GetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bTimerPaused" ) );
        timerDisabled = as<bool>( GetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bIsDisabled" ) );
    }

    // Match is active only if we're not awaiting ready restart and timer is running (not paused and not disabled)
    return !( awaitingReadyRestart || timerPaused || timerDisabled || IsPostRound );
}

// ====================================================================================================
// COMMANDS
// ====================================================================================================

// Command to set a team's ready status
NEW_CMD( CForceReady ) {
    if ( IsMatch() ) return Plugin_Continue;

    if ( args != 2 ) {
        END_CMD( "Usage: sm_force_ready <red|blu> <0|1>" );
    }

    GET_ARG( 1, teamArg, 10 );

    int teamIndex = ParseTeamIndex( teamArg );
    int status    = GetCmdArgInt( 2 );

    // Validate input
    if ( teamIndex == -1 ) END_CMD( "Invalid team. Use 'red' or 'blu'." );
    if ( status < 0 || status > 1 ) END_CMD( "Invalid status. Use 0 (not ready) or 1 (ready)." );

    // Set the team's ready status
    int gameRulesTeamOffset = teamIndex + TEAM_OFFSET;
    GameRules_SetProp( "m_bTeamReady", status, 1, gameRulesTeamOffset );

    // Update our internal tracking
    g_bIsTeamReady[ teamIndex ] = ( status != 0 );

    return Plugin_Handled;
}

// Change client's team
NEW_CMD( CSetTeam ) {
    GET_ARG( 1, target, 33 );
    GET_ARG( 2, input_team, 5 );
    TFTeam team = ParseTeam( input_team );

    if ( args != 2 || team == TFTeam_Unassigned ) END_CMD2( client, "Usage: sm_setteam <#userid|name> <spec|red|blu>" );

    int  target_list[ MAXPLAYERS ];
    char target_name[ MAX_TARGET_LENGTH ];
    bool tn_is_ml     = false;
    int  target_count = ProcessTargetString( target, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, len( target_name ), tn_is_ml );
    bool check        = false;

    if ( target_count == COMMAND_TARGET_NONE ) return Plugin_Handled;

    // Change team of client(s)
    for ( int n = 0; n < target_count; n++ ) {
        int targetId = target_list[ n ];
        if ( !IsValidClient( targetId ) || TF2_GetClientTeam( targetId ) == team ) continue;
        check = true;
        ForcePlayerSuicide( targetId );
        TF2_ChangeClientTeam( targetId, team );
        if ( team != TFTeam_Spectator ) TF2_RespawnPlayer( targetId );
    }

    if ( check ) {
        FOR_EACH_CLIENT( n ) {
            GameRules_SetProp( "m_bTeamReady", 0, .element = n );
        }

        char team_name[ 5 ];
        GetTeamName( as<int>( team ), team_name, len( team_name ) );

        Reply( client, "Switched %s to %s", target_name, team_name );
    }
    return Plugin_Handled;
}

// Set your field of view
NEW_CMD( CSetFOV ) {
    if ( args != 1 ) END_CMD( "Usage: sm_fov <fov>" );

    int fov = GetCmdArgInt( 1 ),
        min = GetConVarInt( g_cvFovMin ),
        max = GetConVarInt( g_cvFovMax );

    if ( fov == 0 ) {
        QueryClientConVar( client, "fov_desired", OnFOVQueried );
        END_CMD( "Your FOV has been reset." );
    }

    if ( fov < min ) END_CMD3( client, "The minimum FOV you can set is %d.", min );
    if ( fov > max ) END_CMD3( client, "The maximum FOV you can set is %d.", max );

    // Try to store in cookies if available
    bool cookieSuccess = false;
    if ( AreClientCookiesCached( client ) ) {
        char cookie[ 4 ];
        IntToString( fov, cookie, len( cookie ) );
        SetClientCookie( client, g_hCookieFOV, cookie );
        cookieSuccess  = true;
        g_bSteamOnline = true;    // Steam is connected if cookies work

        // If we were using backup system but Steam is now connected, we can disable it
        if ( g_bBackupFOVDB ) SetBackupSystem( false );
    } else {
        // Steam is down, initialize backup system if not already done
        if ( !g_bBackupFOVDB ) SetBackupSystem( true );
        g_bSteamOnline             = false;

        // Store in backup system
        g_iPlayerFOV[ client ]     = fov;
        g_bPlayerTracked[ client ] = true;
    }

    // Apply FOV immediately
    SetFOV( client, fov );

    Reply( client, "Your FOV has been set to %d. %s", fov, cookieSuccess ? "" : "(Steam is down, the change will not be permanent.)" );
    return Plugin_Handled;
}

// Save a point
NEW_CMD( CSaveSpawn ) {
    if ( IsMatch() || !g_bSaveEnabled ) END_CMD( "Saving is disabled." );
    if ( client <= 0 || client > MaxClients || !IsClientInGame( client ) ) return Plugin_Handled;
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;

    GetClientAbsOrigin( client, g_vSavePos );
    GetClientEyeAngles( client, g_vSaveAng );
    GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", g_vSaveVel );

    // Save current ammo and clips for carried weapons
    for ( int s = 0; s < MAXSLOTS; s++ ) {
        g_iSavedClip1[ s ]          = -1;
        g_iSavedClip2[ s ]          = -1;
        g_iSavedAmmoType[ s ][ 0 ]  = -1;
        g_iSavedAmmoType[ s ][ 1 ]  = -1;
        g_iSavedAmmoCount[ s ][ 0 ] = 0;
        g_iSavedAmmoCount[ s ][ 1 ] = 0;

        int wep                     = GetPlayerWeaponSlot( client, s );
        if ( wep != -1 ) {
            g_iSavedClip1[ s ]         = GetEntProp( wep, Prop_Send, "m_iClip1" );
            g_iSavedClip2[ s ]         = GetEntProp( wep, Prop_Send, "m_iClip2" );

            int at1                    = GetEntProp( wep, Prop_Send, "m_iPrimaryAmmoType" );
            int at2                    = GetEntProp( wep, Prop_Send, "m_iSecondaryAmmoType" );
            g_iSavedAmmoType[ s ][ 0 ] = at1;
            g_iSavedAmmoType[ s ][ 1 ] = at2;
            if ( at1 >= 0 ) g_iSavedAmmoCount[ s ][ 0 ] = GetEntProp( client, Prop_Send, "m_iAmmo", _, at1 );
            if ( at2 >= 0 ) g_iSavedAmmoCount[ s ][ 1 ] = GetEntProp( client, Prop_Send, "m_iAmmo", _, at2 );
        }
    }
    g_bSavedSpawnValid = true;

    END_CMD( "Spawn saved!" );
}

// Load saved point
NEW_CMD( CLoadSpawn ) {
    if ( IsMatch() || !g_bSaveEnabled ) END_CMD( "Loading is disabled." );
    if ( !IsValidClientAlive( client ) ) return Plugin_Handled;
    if ( args != 0 ) END_CMD( "Usage: sm_load" );
    if ( !g_bSavedSpawnValid ) END_CMD( "No saved spawn point set yet." );

    TeleportEntity( client, g_vSavePos, g_vSaveAng, g_vSaveVel );

    // Restore ammo and clips for current carried weapons
    for ( int s = 0; s < MAXSLOTS; s++ ) {
        int wep = GetPlayerWeaponSlot( client, s );
        if ( wep != -1 ) {
            if ( g_iSavedClip1[ s ] >= 0 ) SetEntProp( wep, Prop_Send, "m_iClip1", g_iSavedClip1[ s ] );
            if ( g_iSavedClip2[ s ] >= 0 ) SetEntProp( wep, Prop_Send, "m_iClip2", g_iSavedClip2[ s ] );
        }

        // Set reserve ammo by ammo types
        int at1 = g_iSavedAmmoType[ s ][ 0 ];
        int at2 = g_iSavedAmmoType[ s ][ 1 ];
        if ( at1 >= 0 ) SetEntProp( client, Prop_Send, "m_iAmmo", g_iSavedAmmoCount[ s ][ 0 ], _, at1 );
        if ( at2 >= 0 ) SetEntProp( client, Prop_Send, "m_iAmmo", g_iSavedAmmoCount[ s ][ 1 ], _, at2 );
    }
    return Plugin_Handled;
}

// Toggle immunity
NEW_CMD( CImmune ) {
    if ( IsMatch() || !g_bImmunityAmmoEnabled ) END_CMD( "Immunity is disabled." );
    if ( args == 0 ) g_bImmunity[ client ] = !g_bImmunity[ client ];
    else END_CMD( "Usage: sm_immune" );

    SetImmunityCookie( client, g_bImmunity[ client ] );

    if ( IsPlayerAlive( client ) ) {
        TF2_RespawnPlayer( client );
        ApplyBootsAttributes( client );
    }

    END_CMD3( client, "Immunity %s.", g_bImmunity[ client ] ? "enabled" : "disabled" );
}

// Toggle infinite ammo
NEW_CMD( CInfAmmo ) {
    if ( IsMatch() || !g_bImmunityAmmoEnabled ) END_CMD( "Infinite ammo is disabled." );
    if ( args == 0 ) g_bInfiniteAmmo[ client ] = !g_bInfiniteAmmo[ client ];
    else END_CMD( "Usage: sm_ammo" );

    SetAmmoCookie( client, g_bInfiniteAmmo[ client ] );

    if ( IsPlayerAlive( client ) ) {
        TF2_RespawnPlayer( client );
        ApplyBootsAttributes( client );
    }

    END_CMD3( client, "Infinite ammo %s.", g_bInfiniteAmmo[ client ] ? "enabled" : "disabled" );
}

// Set a player's class
NEW_CMD( CSetClass ) {
    if ( args != 2 ) END_CMD( "Usage: sm_setclass <#userid|name> <class>" );

    GET_ARG( 2, classArg, 16 );
    TFClassType tfclass = ParseClass( classArg );
    if ( tfclass == TFClass_Unknown ) END_CMD( "Invalid class. Use class name or number" );

    GET_ARG( 1, targetArg, 33 );

    int  targets[ MAXPLAYERS ];
    char target_name[ MAX_TARGET_LENGTH ];
    bool tn_is_ml = false;
    int  count    = ProcessTargetString( targetArg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, len( target_name ), tn_is_ml );
    bool changed  = false;
    if ( count == COMMAND_TARGET_NONE ) return Plugin_Handled;

    for ( int n = 0; n < count; n++ ) {
        int tid = targets[ n ];
        if ( tid <= 0 || tid > MaxClients || !IsClientInGame( tid ) ) continue;
        if ( TF2_GetClientTeam( tid ) == TFTeam_Spectator ) continue;
        TF2_SetPlayerClass( tid, tfclass );
        TF2_RespawnPlayer( tid );
        ApplyBootsAttributes( tid );
        changed = true;
    }

    if ( changed ) {
        char className[ 16 ];
        switch ( tfclass ) {
            case TFClass_Scout: STRCP( className, "Scout" );
            case TFClass_Soldier: STRCP( className, "Soldier" );
            case TFClass_Pyro: STRCP( className, "Pyro" );
            case TFClass_DemoMan: STRCP( className, "Demoman" );
            case TFClass_Heavy: STRCP( className, "Heavy" );
            case TFClass_Engineer: STRCP( className, "Engineer" );
            case TFClass_Medic: STRCP( className, "Medic" );
            case TFClass_Sniper: STRCP( className, "Sniper" );
            case TFClass_Spy: STRCP( className, "Spy" );
            default: STRCP( className, "Unknown" );
        }
        Reply( client, "Set %s class to %s", target_name, className );
    }
    return Plugin_Handled;
}

// Select a random player from targets or custom strings
NEW_CMD( CDice ) {
    if ( args < 1 ) END_CMD2( client, "Usage: sm_dice <\"customstring\" | #userid | playername | @team>" );

    char customStrings[ 10 ][ 64 ];    // Support up to 10 custom strings
    int  customCount = 0;
    int  allTargets[ MAXPLAYERS ];
    int  totalTargetCount = 0;

    // Get the full command string to handle quoted arguments properly
    char fullCmd[ 256 ];
    GetCmdArgString( fullCmd, len( fullCmd ) );

    // Parse arguments manually to handle quotes correctly
    char arguments[ 10 ][ 64 ];
    int  argCount = 0;
    int  pos      = 0;
    int  length   = strlen( fullCmd );

    while ( pos < length && argCount < 10 ) {
        // Skip leading spaces
        while ( pos < length && ( fullCmd[ pos ] == ' ' || fullCmd[ pos ] == '\t' ) ) {
            pos++;
        }

        if ( pos >= length ) break;

        int argStart = pos;
        int argLen   = 0;

        if ( fullCmd[ pos ] == '"' ) {
            // Quoted argument - find closing quote
            pos++;    // Skip opening quote
            argStart = pos;

            while ( pos < length && fullCmd[ pos ] != '"' ) {
                pos++;
            }

            if ( pos < length ) {
                argLen = pos - argStart;
                pos++;    // Skip closing quote
            } else {
                argLen = length - argStart;
            }
        } else {
            // Unquoted argument - read until space
            while ( pos < length && fullCmd[ pos ] != ' ' && fullCmd[ pos ] != '\t' ) {
                pos++;
            }
            argLen = pos - argStart;
        }

        // Copy argument
        if ( argLen > 0 && argLen < len( arguments[] ) ) {
            for ( int copyIdx = 0; copyIdx < argLen && copyIdx < len( arguments[] ) - 1; copyIdx++ ) {
                arguments[ argCount ][ copyIdx ] = fullCmd[ argStart + copyIdx ];
            }
            arguments[ argCount ][ argLen ] = '\0';
            argCount++;
        }
    }

    // Process parsed arguments
    for ( int argIndex = 0; argIndex < argCount; argIndex++ ) {
        char arg[ 64 ];
        STRCP( arg, arguments[ argIndex ] );

        // Check if it looks like a number (custom string)
        bool isNumeric = true;
        for ( int j = 0; j < strlen( arg ); j++ ) {
            if ( arg[ j ] < '0' || arg[ j ] > '9' ) {
                isNumeric = false;
                break;
            }
        }

        if ( isNumeric || strlen( arg ) <= 3 ) {
            // Treat as custom string
            strcopy( customStrings[ customCount ], len( customStrings[] ), arg );
            customCount++;
        } else {
            // Try to process as player target
            TargetStringAlias( arg, sizeof( arg ) );
            int  targets[ MAXPLAYERS ];
            char target_name[ MAX_TARGET_LENGTH ];
            bool tn_is_ml     = false;
            int  target_count = ProcessTargetString( arg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, len( target_name ), tn_is_ml );

            // Add found targets to our combined list (avoid duplicates)
            for ( int n = 0; n < target_count && totalTargetCount < MAXPLAYERS; n++ ) {
                bool alreadyAdded = false;
                for ( int existing = 0; existing < totalTargetCount; existing++ ) {
                    if ( allTargets[ existing ] == targets[ n ] ) {
                        alreadyAdded = true;
                        break;
                    }
                }

                if ( !alreadyAdded ) {
                    allTargets[ totalTargetCount ] = targets[ n ];
                    totalTargetCount++;
                }
            }
        }
    }

    // Determine what to select from
    if ( customCount > 0 && totalTargetCount == 0 ) {
        // Only custom strings - select random custom string
        int random_index = GetRandomInt( 0, customCount - 1 );
        PrintToChatAll( "Rolled %s", customStrings[ random_index ] );
    }
    elif ( totalTargetCount > 0 ) {
        // Players found - select random player
        int  random_index    = GetRandomInt( 0, totalTargetCount - 1 );
        int  selected_player = allTargets[ random_index ];

        char selected_name[ MAX_NAME_LENGTH ];
        GetClientName( selected_player, selected_name, len( selected_name ) );
        PrintToChatAll( "%s was rolled!", selected_name );
    }
    elif ( customCount > 0 ) {
        // Mixed case - select from custom strings
        int random_index = GetRandomInt( 0, customCount - 1 );
        PrintToChatAll( "Rolled %s", customStrings[ random_index ] );
    }
    else {
        Reply( client, "No valid targets or options provided." );
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

// Toggle ready state for the user's team
NEW_CMD( CReady ) {
    if ( IsMatch() ) END_CMD2( client, "Ready command can not be used during a game." );
    if ( args != 0 ) END_CMD2( client, "Usage: sm_ready" );

    // Get client's team
    TFTeam clientTeam = TF2_GetClientTeam( client );
    if ( clientTeam != TFTeam_Red && clientTeam != TFTeam_Blue ) {
        END_CMD2( client, "You must be on RED or BLU team to use this command." );
    }
    char teamColorString[ 10 ];
    if ( clientTeam == TFTeam_Red ) {
        STRCP( teamColorString, "{team_red}" );
    } else {
        STRCP( teamColorString, "{team_blue}" );
    }

    // Convert TF team to array index
    int teamIndex               = ( clientTeam == TFTeam_Red ) ? RED : BLU;
    int gameRulesTeamOffset     = teamIndex + TEAM_OFFSET;

    // Read current ready state from game rules first
    bool currentReadyState = as<bool>( GameRules_GetProp( "m_bTeamReady", _, gameRulesTeamOffset ) );
    
    // Toggle to opposite state
    bool newReadyState = !currentReadyState;
    
    // Update game rules and internal tracking
    GameRules_SetProp( "m_bTeamReady", newReadyState ? 1 : 0, 1, gameRulesTeamOffset );
    g_bIsTeamReady[ teamIndex ] = newReadyState;

    // If team is unreadying during countdown, cancel the countdown
    if ( !newReadyState ) {
        // Check if there's an active countdown timer
        if ( g_iCachedTimerEntity != -1 && IsValidEntity( g_iCachedTimerEntity ) ) {
            bool  timerPaused   = as<bool>( GetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bTimerPaused" ) );
            bool  isDisabled    = as<bool>( GetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bIsDisabled" ) );
            float timeRemaining = GetEntPropFloat( g_iCachedTimerEntity, Prop_Send, "m_fTimeRemaining" );

            // If timer is running and has time remaining, pause it to cancel countdown
            if ( !timerPaused && !isDisabled && timeRemaining > 0.0 ) {
                // Pause the timer and disable auto countdown to stop match start
                SetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bTimerPaused", 1 );
                SetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bAutoCountdown", 0 );
                
                // Also reset timer to ensure it doesn't auto-resume
                SetEntPropFloat( g_iCachedTimerEntity, Prop_Send, "m_fTimeRemaining", 0.0 );
                SetEntProp( g_iCachedTimerEntity, Prop_Send, "m_bIsDisabled", 1 );

                // Announce countdown cancellation
                char teamName[ 8 ];
                STRCP( teamName, ( clientTeam == TFTeam_Red ) ? "RED" : "BLU" );
            }
        }
    }

    // Announce to all players
    char playerName[ MAX_NAME_LENGTH ];
    GetClientName( client, playerName, sizeof( playerName ) );
    switch ( clientTeam ) {
        case TFTeam_Red: CPrintToChatAll( "{teamred}%s {default}changed team state to {steamlightgreen}%s", playerName, newReadyState ? "Ready" : "Not Ready" );
        case TFTeam_Blue: CPrintToChatAll( "{teamblu}%s {default}changed team state to {steamlightgreen}%s", playerName, newReadyState ? "Ready" : "Not Ready" );
    }

    return Plugin_Handled;
}

// Rename team command
NEW_CMD( CTeamName ) {
    if ( IsMatch() ) END_CMD2( client, "Team rename command can only be used during preround." );
    if ( args != 1 ) END_CMD2( client, "Usage: sm_team_name <new_name>" );

    // Get client's team
    TFTeam clientTeam = TF2_GetClientTeam( client );
    if ( clientTeam != TFTeam_Red && clientTeam != TFTeam_Blue ) {
        END_CMD2( client, "You must be on RED or BLU team to use this command." );
    }
    char teamColorString[ 10 ];
    if ( clientTeam == TFTeam_Red ) {
        STRCP( teamColorString, "{team_red}" );
    } else {
        STRCP( teamColorString, "{team_blue}" );
    }

    // Get new team name
    GET_ARG( 1, newName, 64 );

    // Validate name length
    if ( strlen( newName ) < 1 ) END_CMD2( client, "Team name cannot be empty." );
    if ( strlen( newName ) > 5 ) END_CMD2( client, "Team name cannot be longer than 5 characters." );

    // Get team entity
    int teamEntity = FindTeamEntity( as< int >( clientTeam ) );

    if ( teamEntity == -1 ) END_CMD2( client, "Could not find team entity." );

    // Set the team name
    SetEntPropString( teamEntity, Prop_Data, "m_szTeamname", newName );

    // Announce to all players
    char playerName[ MAX_NAME_LENGTH ];
    GetClientName( client, playerName, sizeof( playerName ) );
    switch ( clientTeam ) {
        case TFTeam_Red: CPrintToChatAll( "{teamred}%s {default}changed team name to {steamlightgreen}%s", playerName, newName );
        case TFTeam_Blue: CPrintToChatAll( "{teamblu}%s {default}changed team name to {steamlightgreen}%s", playerName, newName );
    }

    return Plugin_Handled;
}

TFClassType ParseClass( char[] s ) {
    if ( StrEqual( s, "soldier" ) || StrEqual( s, "2" ) ) return TFClass_Soldier;
    if ( StrEqual( s, "demo" ) || StrEqual( s, "demoman" ) || StrEqual( s, "4" ) ) return TFClass_DemoMan;
    if ( StrEqual( s, "med" ) || StrEqual( s, "medic" ) || StrEqual( s, "7" ) ) return TFClass_Medic;
    return TFClass_Unknown;
}

NEW_CMD( CDebugRoundTime ) {
    int ent   = -1;
    int found = 0;

    while ( ( ent = FindEntityByClassname( ent, "team_round_timer" ) ) != -1 ) {
        bool  timerPaused          = as<bool>( GetEntProp( ent, Prop_Send, "m_bTimerPaused" ) );
        float timeRemaining        = GetEntPropFloat( ent, Prop_Send, "m_fTimeRemaining" );
        float timerEndTime         = GetEntPropFloat( ent, Prop_Send, "m_fTimerEndTime" );
        bool  isDisabled           = as<bool>( GetEntProp( ent, Prop_Send, "m_bIsDisabled" ) );
        bool  showInHUD            = as<bool>( GetEntProp( ent, Prop_Send, "m_bShowInHUD" ) );
        int   timerLength          = GetEntProp( ent, Prop_Send, "m_nTimerLength" );
        int   timerInitialLength   = GetEntProp( ent, Prop_Send, "m_nTimerInitialLength" );
        int   timerMaxLength       = GetEntProp( ent, Prop_Send, "m_nTimerMaxLength" );
        bool  autoCountdown        = as<bool>( GetEntProp( ent, Prop_Send, "m_bAutoCountdown" ) );
        int   setupTimeLength      = GetEntProp( ent, Prop_Send, "m_nSetupTimeLength" );
        int   state                = GetEntProp( ent, Prop_Send, "m_nState" );
        bool  startPaused          = as<bool>( GetEntProp( ent, Prop_Send, "m_bStartPaused" ) );
        bool  showTimeRemaining    = as<bool>( GetEntProp( ent, Prop_Send, "m_bShowTimeRemaining" ) );
        bool  inCaptureWatchState  = as<bool>( GetEntProp( ent, Prop_Send, "m_bInCaptureWatchState" ) );
        float totalTime            = GetEntPropFloat( ent, Prop_Send, "m_fTotalTime" );
        bool  stopWatchTimer       = as<bool>( GetEntProp( ent, Prop_Send, "m_bStopWatchTimer" ) );

        // Check if game is ongoing using m_bAwaitingReadyRestart and timer pause state
        bool  awaitingReadyRestart = as<bool>( GameRules_GetProp( "m_bAwaitingReadyRestart" ) );
        bool  gameOngoing          = !awaitingReadyRestart && !timerPaused && !isDisabled;

        Reply( client, "[timer %d] m_bTimerPaused=%d m_fTimeRemaining=%.2f m_fTimerEndTime=%.2f m_bIsDisabled=%d m_bShowInHUD=%d", ent, timerPaused, timeRemaining, timerEndTime, isDisabled, showInHUD );
        Reply( client, "[timer %d] m_nTimerLength=%d m_nTimerInitialLength=%d m_nTimerMaxLength=%d m_bAutoCountdown=%d", ent, timerLength, timerInitialLength, timerMaxLength, autoCountdown );
        Reply( client, "[timer %d] m_nSetupTimeLength=%d m_nState=%d m_bStartPaused=%d m_bShowTimeRemaining=%d", ent, setupTimeLength, state, startPaused, showTimeRemaining );
        Reply( client, "[timer %d] m_bInCaptureWatchState=%d m_fTotalTime=%.2f m_bStopWatchTimer=%d", ent, inCaptureWatchState, totalTime, stopWatchTimer );
        Reply( client, "[timer %d] Game Ongoing: %d (m_bAwaitingReadyRestart=%d)", ent, gameOngoing, awaitingReadyRestart );

        found++;
    }

    if ( found == 0 ) END_CMD2( client, "No team_round_timer found." );
    return Plugin_Handled;
}

// Get current round state
NEW_CMD( CGetRoundState ) {
    int  currentState = GameRules_GetRoundState();
    char stateName[ 32 ];
    RoundStateName( currentState, stateName, len( stateName ) );

    ReplyToCommand( client, "Current round state: %d (%s)", currentState, stateName );
    return Plugin_Handled;
}

// Toggle round state update printing
NEW_CMD( CPrintRoundStateUpdate ) {
    if ( args != 0 ) END_CMD2( client, "Usage: sm_print_round_state_update" );

    g_bPrintRoundStateUpdates = !g_bPrintRoundStateUpdates;

    Reply( client, "Round state update printing %s", g_bPrintRoundStateUpdates ? "ENABLED" : "DISABLED" );
    return Plugin_Handled;
}

// ====================================================================================================
// BACKUP COMMANDS
// ====================================================================================================

// Backup toggle for resupply
NEW_CMD( CToggleResupply ) {
    if ( args != 1 ) END_CMD2( client, "Usage: sm_enable_resupply <0|1>" );

    GET_ARG( 1, arg, 4 );
    int value = StringToInt( arg );

    if ( value != 0 && value != 1 ) END_CMD2( client, "Usage: sm_enable_resupply <0|1> (0=disable, 1=enable)" );

    g_bResupplyEnabled = ( value != 0 );

    END_CMD3( client, "Resupply functionality %s", g_bResupplyEnabled ? "ENABLED" : "DISABLED" );
}

// Backup toggle for instant respawn
NEW_CMD( CToggleRespawn ) {
    if ( args != 1 ) END_CMD2( client, "Usage: sm_enable_respawn <0|1>" );

    GET_ARG( 1, arg, 4 );
    int value = StringToInt( arg );

    if ( value != 0 && value != 1 ) END_CMD2( client, "Usage: sm_enable_respawn <0|1>" );

    g_bInstantRespawnEnabled = ( value != 0 );

    END_CMD3( client, "Instant respawn %s", g_bInstantRespawnEnabled ? "enabled" : "disabled" );
}

// Backup toggle for immunity and infinite ammo
NEW_CMD( CToggleImmunity ) {
    if ( args != 1 ) END_CMD2( client, "Usage: sm_enable_immunity <0|1>" );

    GET_ARG( 1, arg, 4 );
    int value = StringToInt( arg );

    if ( value != 0 && value != 1 ) END_CMD2( client, "Usage: sm_enable_immunity <0|1> (0=disable, 1=enable)" );

    g_bImmunityAmmoEnabled = ( value != 0 );

    // If disabling, turn off immunity and infinite ammo for all players
    if ( !g_bImmunityAmmoEnabled ) {
        FOR_EACH_CLIENT( n ) {
            if ( IsClientInGame( n ) ) {
                g_bImmunity[ n ]          = false;
                g_bInfiniteAmmo[ n ]      = false;
                g_bStaticAmmoValid[ n ]   = false;
            }
        }
    }

    END_CMD3( client, "Immunity and infinite ammo %s", g_bImmunityAmmoEnabled ? "ENABLED" : "DISABLED" );
}

// Backup toggle for save/load
NEW_CMD( CToggleSave ) {
    if ( args != 1 ) END_CMD2( client, "Usage: sm_enable_saveload <0|1>" );

    GET_ARG( 1, arg, 4 );
    int value = StringToInt( arg );

    if ( value != 0 && value != 1 ) END_CMD2( client, "Usage: sm_enable_saveload <0|1> (0=disable, 1=enable)" );

    g_bSaveEnabled = ( value != 0 );

    END_CMD3( client, "Save/Load spawn functionality %s", g_bSaveEnabled ? "ENABLED" : "DISABLED" );
}

// Backup toggle for demo blast vulnerability
NEW_CMD( CToggleDemoResist ) {
    if ( args != 1 ) END_CMD2( client, "Usage: sm_enable_demoresist <0|1>" );

    GET_ARG( 1, arg, 4 );
    int value = StringToInt( arg );

    if ( value != 0 && value != 1 ) END_CMD2( client, "Usage: sm_enable_demoresist <0|1>" );

    g_bDemoResistEnabled = ( value != 0 );

    // Apply resistance changes to all connected players
    FOR_EACH_CLIENT( n ) {
        if ( IsClientInGame( n ) ) {
            ApplyDemoResistance( n );
        }
    }

    END_CMD3( client, "Demo blast vulnerability %s", g_bDemoResistEnabled ? "ENABLED" : "DISABLED" );
}

// Debug command to list entities with blast attributes
NEW_CMD( CListBlastAttrib ) {
    int count = 0;
    FOR_EACH_CLIENT( n ) {
        if ( IsClientInGame( n ) && g_bDemoResistApplied[ n ] ) {
            char name[ MAX_NAME_LENGTH ];
            GetClientName( n, name, len( name ) );
            Reply( client, "Player %s (ID: %d) has blast resistance value: %.2f", name, n, g_fCurrentDemoResistValue[ n ] );
            count++;
        }
    }

    if ( count == 0 ) {
        Reply( client, "No players currently have blast resistance attributes applied." );
    } else {
        Reply( client, "Total players with blast resistance: %d", count );
    }

    return Plugin_Handled;
}

// Add prefix tag to all players on a team
NEW_CMD( CAddTag ) {
    if ( args != 2 ) END_CMD2( client, "Usage: sm_add_tag <red|blu> <tag>" );

    GET_ARG( 1, teamArg, 10 );
    GET_ARG( 2, tagArg, 8 );

    int teamIndex; TFTeam targetTeam; char teamName[ 4 ];
    if ( !ValidateTagArgs( client, teamArg, tagArg, teamIndex, targetTeam, teamName ) ) return Plugin_Handled;

    int playersTagged = 0;
    FOR_EACH_CLIENT( n ) {
        if ( !IsClientInGame( n ) || IsFakeClient( n ) ) continue;
        if ( TF2_GetClientTeam( n ) != targetTeam ) continue;

        char currentName[ MAX_NAME_LENGTH ];
        GetClientName( n, currentName, len( currentName ) );

        // Skip if already has tag at start
        if ( StrContains( currentName, tagArg, false ) == 0 ) continue;

        char newName[ MAX_NAME_LENGTH ];
        Format( newName, len( newName ), "%s %s", tagArg, currentName );

        // Truncate if too long
        if ( strlen( newName ) > MAX_NAME_LENGTH - 1 ) {
            int maxLen = MAX_NAME_LENGTH - strlen( tagArg ) - 2;
            if ( maxLen <= 0 ) continue;
            char truncated[ MAX_NAME_LENGTH ];
            strcopy( truncated, maxLen + 1, currentName );
            Format( newName, len( newName ), "%s %s", tagArg, truncated );
        }

        SetClientName( n, newName );
        playersTagged++;
    }

    if ( playersTagged > 0 ) {
        char adminName[ MAX_NAME_LENGTH ];
        GetClientName( client, adminName, len( adminName ) );
        PrintToChatAll( "Admin %s added tag \"%s\" to %d players on team %s", adminName, tagArg, playersTagged, teamName );
        Reply( client, "Successfully added tag \"%s\" to %d players on team %s", tagArg, playersTagged, teamName );
    } else {
        Reply( client, "No players were tagged on team %s (team empty or all players already have this tag)", teamName );
    }

    return Plugin_Handled;
}

// Remove prefix tag from all players on a team
NEW_CMD( CRemoveTag ) {
    if ( args != 2 ) END_CMD2( client, "Usage: sm_remove_tag <red|blu> <tag>" );

    GET_ARG( 1, teamArg, 10 );
    GET_ARG( 2, tagArg, 8 );

    int teamIndex; TFTeam targetTeam; char teamName[ 4 ];
    if ( !ValidateTagArgs( client, teamArg, tagArg, teamIndex, targetTeam, teamName ) ) return Plugin_Handled;

    int    playersUntagged = 0;
    char   tagWithSpace[ 10 ];
    Format( tagWithSpace, len( tagWithSpace ), "%s ", tagArg );

    FOR_EACH_CLIENT( n ) {
        if ( !IsClientInGame( n ) || IsFakeClient( n ) ) continue;
        if ( TF2_GetClientTeam( n ) != targetTeam ) continue;

        char currentName[ MAX_NAME_LENGTH ];
        GetClientName( n, currentName, len( currentName ) );

        if ( StrContains( currentName, tagWithSpace, false ) != 0 ) continue;

        char newName[ MAX_NAME_LENGTH ];
        STRCP( newName, currentName[ strlen( tagWithSpace ) ] );
        if ( strlen( newName ) < 1 ) STRCP( newName, "Player" );

        SetClientName( n, newName );
        playersUntagged++;
    }

    if ( playersUntagged > 0 ) {
        char adminName[ MAX_NAME_LENGTH ];
        GetClientName( client, adminName, len( adminName ) );
        PrintToChatAll( "Admin %s removed tag \"%s\" from %d players on team %s", adminName, tagArg, playersUntagged, teamName );
        Reply( client, "Successfully removed tag \"%s\" from %d players on team %s", tagArg, playersUntagged, teamName );
    } else {
        Reply( client, "No players had tag \"%s\" removed on team %s", tagArg, teamName );
    }

    return Plugin_Handled;
}

// ====================================================================================================
// EVENTS
// ====================================================================================================

// Handle player death event
public Action EPDeath( Event event, const char[] name, bool dontBroadcast ) {
    if ( IsMatch() ) return Plugin_Continue;

    int client = GetClientOfUserId( event.GetInt( "userid" ) );

    // Validate client before proceeding
    if ( !IsValidClient( client ) ) return Plugin_Continue;

    // Check if instant respawn is globally enabled
    if ( g_bInstantRespawnEnabled && g_cvRespawnTime.FloatValue <= 0.0 ) {
        RequestFrame( RespawnFrame, client );
    }

    return Plugin_Continue;
}

// Player disconnect event - clean up tracking
NEW_EV( EPDisconnect ) {
    int userid = event.GetInt( "userid" );
    int client = GetClientOfUserId( userid );

    if ( client > 0 && client <= MaxClients && g_bBackupFOVDB ) {
        // Clear tracking data for this slot if backup system is active
        g_bPlayerTracked[ client ] = false;
        g_iPlayerFOV[ client ]     = 0;
    }
}

// Restores the client's FOV, infinite ammo, and immunity settings on spawn
NEW_EV( EPSpawn ) {
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !IsValidClient( client ) ) return;

    ApplyDemoResistance( client );
    ApplyBootsAttributes( client );

    // Try to restore settings from cookies first
    if ( AreClientCookiesCached( client ) ) {
        if ( GetFOVCookie( client ) ) {
            // If we were using backup but Steam is now connected, we can disable it
            if ( !g_bSteamOnline ) {
                g_bSteamOnline = true;
                if ( g_bBackupFOVDB ) SetBackupSystem( false );
            }
        }

        // Restore infinite ammo and immunity settings
        GetAmmoCookie( client );
        GetImmunityCookie( client );
        return;
    }
    elif ( !g_bBackupFOVDB ) {
        // Steam is down, initialize backup system
        SetBackupSystem( true );
        g_bSteamOnline = false;
    }

    // If cookies failed or aren't cached, try backup system
    if ( g_bBackupFOVDB && g_bPlayerTracked[ client ] && g_iPlayerFOV[ client ] > 0 ) {
        SetFOV( client, g_iPlayerFOV[ client ] );
    }

    // Restore from backup system for infinite ammo and immunity
    if ( g_bBackupInfiniteAmmoTracked[ client ] ) {
        g_bInfiniteAmmo[ client ] = g_bBackupInfiniteAmmo[ client ];
        if ( g_bInfiniteAmmo[ client ] ) {
            SetInitAmmo( client );
        }
    }

    if ( g_bBackupImmunityTracked[ client ] ) {
        g_bImmunity[ client ] = g_bBackupImmunity[ client ];
    }
}

NEW_EV( EPInventoryApplication ) {
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !IsValidClient( client ) ) return;

    ApplyBootsAttributes( client );
}

// Round state change handlers
NEW_EV( EPRoundStart ) {
    UpdateRoundState( RoundState_StartGame );
}

NEW_EV( EPRoundActive ) {
    UpdateRoundState( RoundState_RoundRunning );
}

NEW_EV( EPRoundRestart ) {
    UpdateRoundState( RoundState_Restart );
}

NEW_EV( EPRoundWin ) {
    UpdateRoundState( RoundState_TeamWin );
}

NEW_EV( EPRoundGameOver ) {
    UpdateRoundState( RoundState_GameOver );
}

// Update round state and print if enabled
void UpdateRoundState( int newState ) {
    int oldState         = g_iCurrentRoundState;
    g_iCurrentRoundState = newState;

    if ( g_bPrintRoundStateUpdates && oldState != newState ) {
        char oldStateName[ 32 ], newStateName[ 32 ];
        RoundStateName( oldState, oldStateName, len( oldStateName ) );
        RoundStateName( newState, newStateName, len( newStateName ) );
        PrintToChatAll( "[Round State] %s -> %s", oldStateName, newStateName );
    }
}

// Retrieves the client's FOV from their local config and stores it in a cookie
public OnFOVQueried( QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] fov ) {
    if ( result != ConVarQuery_Okay ) return;
    SetClientCookie( client, g_hCookieFOV, "" );
    SetFOV( client, StringToInt( fov ) );
}

// ====================================================================================================
// HELPERS
// ====================================================================================================

// Get the name of a round state as a string
void RoundStateName( int state, char[] buffer, int size ) {
    switch ( state ) {
        case RoundState_Init: strcopy( buffer, size, "Init" );
        case RoundState_Pregame: strcopy( buffer, size, "Pregame" );
        case RoundState_StartGame: strcopy( buffer, size, "StartGame" );
        case RoundState_Preround: strcopy( buffer, size, "Preround" );
        case RoundState_RoundRunning: strcopy( buffer, size, "RoundRunning" );
        case RoundState_TeamWin: strcopy( buffer, size, "TeamWin" );
        case RoundState_Restart: strcopy( buffer, size, "Restart" );
        case RoundState_Stalemate: strcopy( buffer, size, "Stalemate" );
        case RoundState_GameOver: strcopy( buffer, size, "GameOver" );
        case RoundState_Bonus: strcopy( buffer, size, "Bonus" );
        case RoundState_BetweenRounds: strcopy( buffer, size, "BetweenRounds" );
        default: strcopy( buffer, size, "Unknown" );
    }
}

// Validate team and tag arguments for CAddTag/CRemoveTag
bool ValidateTagArgs( int client, const char[] teamArg, const char[] tagArg, int &teamIndex, TFTeam &targetTeam, char teamName[ 4 ] ) {
    teamIndex = ParseTeamIndex( teamArg );
    if ( teamIndex == -1 ) { Reply( client, "Invalid team. Use 'red|r' or 'blu|blue|b'." ); return false; }
    if ( strlen( tagArg ) < 1 ) { Reply( client, "Tag cannot be empty." ); return false; }
    if ( strlen( tagArg ) > 7 ) { Reply( client, "Tag cannot be longer than 7 characters." ); return false; }

    targetTeam = ( teamIndex == RED ) ? as<TFTeam>( TFTeam_Red ) : as<TFTeam>( TFTeam_Blue );
    if ( teamIndex == RED ) STRCP( teamName, "RED" );
    else STRCP( teamName, "BLU" );
    return true;
}

// Find a tf_team entity by team number (2=RED, 3=BLU)
int FindTeamEntity( int teamNum ) {
    int entity = -1;
    while ( ( entity = FindEntityByClassname( entity, "tf_team" ) ) != -1 ) {
        if ( GetEntProp( entity, Prop_Send, "m_iTeamNum" ) == teamNum ) return entity;
    }
    return -1;
}

// Sends a message to the client and returns PH
Action EndCommand( int client, const char[] format, any... ) {
    char buffer[ 254 ];
    VFormat( buffer, len( buffer ), format, 3 );
    Reply( client, "%s", buffer );
    return Plugin_Handled;
}

// Checks if a client in-game, connected, not fake, and in a valid team
bool IsValidClient( int client ) {
    return IsClientInGame( client ) && !IsFakeClient( client ) && IsClientConnected( client );
}

// Checks if a client in-game, connected, not fake, in a valid team, and alive
bool IsValidClientAlive( int client ) {
    return IsValidClient( client ) && IsPlayerAlive( client );
}

// Sets the client's FOV
SetFOV( int client, int fov ) {
    SetEntProp( client, Prop_Send, "m_iFOV", fov );
    SetEntProp( client, Prop_Send, "m_iDefaultFOV", fov );
}

// Retrieves the client's FOV from the cookie and applies it, returns false if invalid
bool GetFOVCookie( int client ) {
    char cookie[ 4 ];
    GetClientCookie( client, g_hCookieFOV, cookie, len( cookie ) );
    int fov = StringToInt( cookie ),
        min = GetConVarInt( g_cvFovMin ),
        max = GetConVarInt( g_cvFovMax );

    if ( fov < min || fov > max ) return false;

    // If backup system is active, update it with cookie value
    if ( g_bBackupFOVDB ) {
        g_iPlayerFOV[ client ]     = fov;
        g_bPlayerTracked[ client ] = true;
    }

    SetFOV( client, fov );
    return true;
}

// Parse TFTeam from string
TFTeam ParseTeam( char[] team ) {
    return StrEqual( team, "spectator" ) || StrEqual( team, "spec" ) || StrEqual( team, "s" ) ? TFTeam_Spectator
         : StrEqual( team, "red" ) || StrEqual( team, "r" )                                   ? TFTeam_Red
         : StrEqual( team, "blue" ) || StrEqual( team, "blu" ) || StrEqual( team, "b" )       ? TFTeam_Blue
                                                                                              : TFTeam_Unassigned;
}

// Converts team name string to RED/BLU constants
int ParseTeamIndex( char[] team ) {
    return StrEqual( team, "red" ) || StrEqual( team, "r" )                             ? RED
         : StrEqual( team, "blu" ) || StrEqual( team, "blue" ) || StrEqual( team, "b" ) ? BLU
                                                                                        : -1;
}

// Replaces @r, @blu, @b, @s, @spectator with @red, @blue, @spec
void TargetStringAlias( char[] target, int size ) {
    if ( StrEqual( target, "@r", false ) ) strcopy( target, size, "@red" );
    elif ( StrEqual( target, "@blu", false ) || StrEqual( target, "@b", false ) ) strcopy( target, size, "@blue" );
    elif ( StrEqual( target, "@s", false ) || StrEqual( target, "@spectator", false ) ) strcopy( target, size, "@spec" );
}

// Enable or disable the backup system based on Steam connection status
SetBackupSystem( bool a ) {
    if ( g_bBackupFOVDB == a ) return;    // Already in desired state
    g_bBackupFOVDB = a;
    // Initialize/clear player tracking arrays
    FOR_EACH_CLIENT( client ) {
        g_iPlayerFOV[ client ]                 = 0;
        g_bPlayerTracked[ client ]             = false;
        g_bBackupInfiniteAmmoTracked[ client ] = false;
        g_bBackupImmunityTracked[ client ]     = false;
        g_bBackupInfiniteAmmo[ client ]        = false;
        g_bBackupImmunity[ client ]            = false;
    }

    if ( a ) PrintToServer( "Backup system enabled - Steam connection is down" );
    else PrintToServer( "Backup system disabled - Steam connection restored" );
}

// Respawn frame callback
public void RespawnFrame( any client ) {
    if ( !IsPlayerAlive( client ) ) TF2_RespawnPlayer( client );
}

// Command for when resupply key is pressed
NEW_CMD( CResupDn ) {
    // Check if resupply is globally enabled
    if ( !g_bResupplyEnabled ) END_CMD2( client, "Resupply is disabled." );

    // Check if client is valid
    if ( !IsClientInGame( client ) ) END_CMD2( client, "You must be in-game to use this command." );

    // Mark the key as down and reset used flag
    g_bResupplyDn[ client ] = true;
    g_bResupplyUp[ client ] = false;

    // Try to resupply immediately if in spawn room
    Resupply( client );

    return Plugin_Handled;
}

// Command for when resupply key is released
NEW_CMD( CResupUp ) {
    // Check if client is valid
    if ( !IsClientInGame( client ) ) return Plugin_Handled;

    // Check if resupply is globally enabled
    if ( !g_bResupplyEnabled ) return Plugin_Handled;

    // Mark the key as up
    g_bResupplyDn[ client ] = false;
    return Plugin_Handled;
}

// Try to resupply a player if conditions are met
void Resupply( int client ) {
    if ( !IsValidClientAlive( client ) ) return;
    // Check if resupply is globally enabled
    if ( !g_bResupplyEnabled ) return;

    // Check if key is down and resupply hasn't been used yet
    if ( !g_bResupplyDn[ client ] || g_bResupplyUp[ client ] ) return;

    if ( !IsClientInSpawnroom( client ) ) return;

    // Try to use side-aware spawnpoint selection if mirror system is available
    if ( g_bMirrorSystemOn ) {
        // Get client's team and position
        TFTeam clientTeam = TF2_GetClientTeam( client );
        if ( clientTeam == TFTeam_Red || clientTeam == TFTeam_Blue ) {
            int   teamIndex = ( clientTeam == TFTeam_Red ) ? RED : BLU;

            // Get player's current position
            float playerOrigin[ 3 ];
            GetClientAbsOrigin( client, playerOrigin );

            // Determine which side of the plane the player is on
            int       currentSide  = ( playerOrigin[ 0 ] < g_fMirrorPlaneX ) ? 0 : 1;    // 0 = left, 1 = right
            int       targetSide   = ( currentSide == 0 ) ? 1 : 0;                       // Opposite side

            // Get spawnpoints for the opposite side of the player's team
            ArrayList targetSpawns = g_hMirrorSpawnPoints[ teamIndex ][ targetSide ];

            if ( targetSpawns.Length > 0 ) {
                // Use sequential spawnpoint selection (vanilla TF2 behavior)
                int spawnIndex                                  = g_iCurrentSpawnIndex[ teamIndex ][ targetSide ];
                int spawnEntity                                 = targetSpawns.Get( spawnIndex );

                // Increment index for next spawn and wrap around if needed
                g_iCurrentSpawnIndex[ teamIndex ][ targetSide ] = ( spawnIndex + 1 ) % targetSpawns.Length;

                if ( IsValidEntity( spawnEntity ) ) {
                    // Get spawnpoint position and angles
                    float spawnOrigin[ 3 ], spawnAngles[ 3 ];
                    GetEntPropVector( spawnEntity, Prop_Data, "m_vecOrigin", spawnOrigin );
                    GetEntPropVector( spawnEntity, Prop_Data, "m_angRotation", spawnAngles );

                    // Respawn player and teleport to same side spawnpoint
                    TF2_RespawnPlayer( client );
                    TeleportEntity( client, spawnOrigin, spawnAngles, { 0.0, 0.0, 0.0 } );

                    // Reapply boots attributes after resupply
                    ApplyBootsAttributes( client );

                    g_bResupplyUp[ client ] = true;
                    return;
                }
            }
        }
    }

    // Fallback to default TF2 respawn behavior
    TF2_RespawnPlayer( client );

    // Reset player velocity to zero
    TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, { 0.0, 0.0, 0.0 } );

    // Reapply boots attributes after resupply
    ApplyBootsAttributes( client );

    g_bResupplyUp[ client ] = true;
}

// Check if a player is within the bounds of a brush entity
bool IsColliding( int client, int entity ) {
    // Get player hull
    float playerMins[ 3 ], playerMaxs[ 3 ];
    GetClientMins( client, playerMins );
    GetClientMaxs( client, playerMaxs );

    // Get player position
    float playerPos[ 3 ];
    GetClientAbsOrigin( client, playerPos );

    // Calculate player hull bounds in world space
    float playerHullMins[ 3 ], playerHullMaxs[ 3 ];
    for ( int n = 0; n < 3; n++ ) {
        playerHullMins[ n ] = playerPos[ n ] + playerMins[ n ];
        playerHullMaxs[ n ] = playerPos[ n ] + playerMaxs[ n ];
    }

    // Get entity bounds - use Prop_Data for accurate values and add origin for absolute coordinates
    float entityOrigin[ 3 ], entityMins[ 3 ], entityMaxs[ 3 ];
    GetEntPropVector( entity, Prop_Data, "m_vecOrigin", entityOrigin );
    GetEntPropVector( entity, Prop_Data, "m_vecMins", entityMins );
    GetEntPropVector( entity, Prop_Data, "m_vecMaxs", entityMaxs );

    // Convert relative bounds to absolute world coordinates
    float entityAbsMins[ 3 ], entityAbsMaxs[ 3 ];
    AddVectors( entityOrigin, entityMins, entityAbsMins );
    AddVectors( entityOrigin, entityMaxs, entityAbsMaxs );

    // Check if player hull intersects with entity bounds (now in absolute coordinates)
    return ( playerHullMaxs[ 0 ] >= entityAbsMins[ 0 ] && playerHullMins[ 0 ] <= entityAbsMaxs[ 0 ] && playerHullMaxs[ 1 ] >= entityAbsMins[ 1 ] && playerHullMins[ 1 ] <= entityAbsMaxs[ 1 ] && playerHullMaxs[ 2 ] >= entityAbsMins[ 2 ] && playerHullMins[ 2 ] <= entityAbsMaxs[ 2 ] );
}

// Check if a player is touching any func_respawnroom entities of their own team
bool IsClientInSpawnroom( int client ) {
    // Use cached spawn room entities instead of searching
    int clientTeam = GetClientTeam( client );

    for ( int idx = 0; idx < g_hCachedSpawnRooms.Length; idx++ ) {
        int spawnroom = g_hCachedSpawnRooms.Get( idx );
        if ( IsValidEntity( spawnroom ) && GetEntProp( spawnroom, Prop_Send, "m_iTeamNum" ) == clientTeam && IsColliding( client, spawnroom ) ) {
            if ( IsTooFarFromSpawnpoint( client ) ) return false;
            return true;
        }
    }
    return false;
}

// Get distance to nearest spawn point of player's team
bool IsTooFarFromSpawnpoint( int client ) {
    float playerPos[ 3 ];
    GetClientAbsOrigin( client, playerPos );

    float nearestDistance = 100000.0;
    int   clientTeam      = GetClientTeam( client );
    int   teamIndex       = ( clientTeam == 2 ) ? RED : BLU;    // Convert TF team to array index

    // Use cached spawn points instead of searching
    if ( g_hCachedSpawnPoints[ teamIndex ] != null ) {
        for ( int idx = 0; idx < g_hCachedSpawnPoints[ teamIndex ].Length; idx++ ) {
            int spawn = g_hCachedSpawnPoints[ teamIndex ].Get( idx );
            if ( !IsValidEntity( spawn ) ) continue;

            float spawnPos[ 3 ];
            GetEntPropVector( spawn, Prop_Send, "m_vecOrigin", spawnPos );

            float distance = GetVectorDistance( playerPos, spawnPos );
            if ( distance < nearestDistance ) nearestDistance = distance;
        }
    }

    return nearestDistance >= RESUPDIST;
}

// Called when a client disconnects
public OnClientDisconnect( int client ) {
    g_bResupplyDn[ client ]                = false;
    g_bResupplyUp[ client ]                = false;
    g_bImmunity[ client ]                  = false;
    g_bPendingHP[ client ]                 = false;
    g_iPreDamageHP[ client ]               = 0;
    g_bInfiniteAmmo[ client ]              = false;

    // Reset backup tracking for infinite ammo and immunity
    g_bBackupInfiniteAmmoTracked[ client ] = false;
    g_bBackupImmunityTracked[ client ]     = false;
    g_bBackupInfiniteAmmo[ client ]        = false;
    g_bBackupImmunity[ client ]            = false;

    // Clean up performance optimization tracking
    g_fCurrentDemoResistValue[ client ] = 0.0;
    g_bDemoResistApplied[ client ]      = false;
    g_bStaticAmmoValid[ client ]        = false;

    // Clear static ammo array
    for ( int j = 0; j < 34; j++ ) {
        g_iStaticOriginalAmmo[ client ][ j ] = 0;
    }
}

void SetAmmo( int client, int weapon, int ammo ) {
    if ( IsValidEntity( weapon ) ) {
        int offset   = GetEntProp( weapon, Prop_Send, "m_iPrimaryAmmoType", 1 ) * 4;
        int ammotype = FindSendPropInfo( "CTFPlayer", "m_iAmmo" ) + offset;
        SetEntData( client, ammotype, ammo, 4, true );
    }
}

int TF2_GetPlayerMaxHealth( int client ) {
    return GetEntProp( GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client );
}

void RegAdminCmdWithShort( const char[] cmd,
                           const char[] shortcmd,
                           ConCmd callback,
                           int    adminflags,
                           const char[] description = "",
                           const char[] group       = "",
                           int flags                = 0 ) {
    RegAdminCmd( cmd, callback, adminflags, description, group, flags );
    RegAdminCmd( shortcmd, callback, adminflags, description, group, flags );
}

void RegConsoleCmdWithShort( const char[] cmd,
                             const char[] shortcmd,
                             ConCmd callback,
                             const char[] description = "",
                             int flags                = 0 ) {
    RegConsoleCmd( cmd, callback, description, flags );
    RegConsoleCmd( shortcmd, callback, description, flags );
}

// ====================================================================================================
// FORWARDS
// ====================================================================================================

// Called when a client's cookies have been loaded
public void OnClientCookiesCached( int client ) {
    // Steam connection is now available
    g_bSteamOnline = true;

    // If we were using backup system but Steam is now connected, we can disable it
    if ( g_bBackupFOVDB ) SetBackupSystem( false );

    // Try to load from cookies
    GetFOVCookie( client );
    GetAmmoCookie( client );
    GetImmunityCookie( client );
}

void SetAmmoCookie( int client, bool enabled ) {
    if ( AreClientCookiesCached( client ) ) {
        char value[ 2 ];
        IntToString( enabled ? 1 : 0, value, len( value ) );
        SetClientCookie( client, g_hCookieInfiniteAmmo, value );
        g_bSteamOnline = true;

        if ( g_bBackupFOVDB ) SetBackupSystem( false );
    } else {
        if ( !g_bBackupFOVDB ) SetBackupSystem( true );
        g_bSteamOnline                 = false;
        g_bBackupInfiniteAmmo[ client ] = enabled;
        g_bBackupInfiniteAmmoTracked[ client ] = true;
    }
}

bool GetAmmoCookie( int client ) {
    char value[ 2 ];
    GetClientCookie( client, g_hCookieInfiniteAmmo, value, len( value ) );

    if ( strlen( value ) == 0 ) return false;

    bool enabled = ( StringToInt( value ) != 0 );
    g_bInfiniteAmmo[ client ] = enabled;

    if ( g_bBackupFOVDB ) {
        g_bBackupInfiniteAmmo[ client ]        = enabled;
        g_bBackupInfiniteAmmoTracked[ client ] = true;
    }

    // Store original ammo if enabling
    if ( g_bInfiniteAmmo[ client ] && IsValidClient( client ) ) {
        SetInitAmmo( client );
    }
    return true;
}

void SetImmunityCookie( int client, bool enabled ) {
    if ( AreClientCookiesCached( client ) ) {
        char value[ 2 ];
        IntToString( enabled ? 1 : 0, value, len( value ) );
        SetClientCookie( client, g_hCookieImmunity, value );
        g_bSteamOnline = true;

        if ( g_bBackupFOVDB ) SetBackupSystem( false );
    } else {
        if ( !g_bBackupFOVDB ) SetBackupSystem( true );
        g_bSteamOnline             = false;
        g_bBackupImmunity[ client ] = enabled;
        g_bBackupImmunityTracked[ client ] = true;
    }
}

bool GetImmunityCookie( int client ) {
    char value[ 2 ];
    GetClientCookie( client, g_hCookieImmunity, value, len( value ) );

    if ( strlen( value ) == 0 ) return false;

    bool enabled = ( StringToInt( value ) != 0 );
    g_bImmunity[ client ] = enabled;

    if ( g_bBackupFOVDB ) {
        g_bBackupImmunity[ client ]        = enabled;
        g_bBackupImmunityTracked[ client ] = true;
    }

    return true;
}

// Store the client's current ammo state
public void SetInitAmmo( int client ) {
    // Get the active weapon
    int weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
    if ( weapon == -1 || !IsValidEntity( weapon ) ) return;

    // Store clip values in static array
    g_iStaticOriginalAmmo[ client ][ 0 ] = GetEntProp( weapon, Prop_Send, "m_iClip1" );
    g_iStaticOriginalAmmo[ client ][ 1 ] = GetEntProp( weapon, Prop_Send, "m_iClip2" );

    // Store reserve ammo values for all ammo types
    for ( int ammoType = 0; ammoType < 32; ammoType++ ) {
        g_iStaticOriginalAmmo[ client ][ ammoType + 2 ] = GetEntProp( client, Prop_Send, "m_iAmmo", _, ammoType );
    }

    g_bStaticAmmoValid[ client ] = true;
}

// SDKHooks damage filter: prevent/zero damage if victim is protected or attacker is restricted
public Action Hook_OnTakeDamage( int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[ 3 ], float damagePosition[ 3 ], int damagecustom ) {
    if ( IsMatch() ) return Plugin_Continue;
    if ( g_bImmunity[ victim ] ) {
        int health             = GetClientHealth( victim );
        g_bPendingHP[ victim ] = true;

        if ( health <= damage ) damage = health - 1.0;
        return Plugin_Changed;
    }
    if ( attacker >= 1 && attacker <= MaxClients && g_bImmunity[ attacker ] ) {
        if ( damage > 0.0 ) damage = 0.0;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

public void Hook_OnTakeDamagePost( int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, float damageForce[ 3 ], float damagePosition[ 3 ], int damagecustom ) {
    if ( IsMatch() ) return;

    if ( g_bPendingHP[ victim ] ) {
        g_bPendingHP[ victim ] = false;
        if ( IsValidClientAlive( victim ) ) SetEntityHealth( victim, TF2_GetPlayerMaxHealth( victim ) );
    }
}

// ====================================================================================================
// PERFORMANCE OPTIMIZATION HELPER FUNCTIONS
// ====================================================================================================

// Build entity cache
void BuildEntityCache() {
    // Clear existing cache
    g_hCachedSpawnRooms.Clear();
    g_hCachedSpawnPoints[ RED ].Clear();
    g_hCachedSpawnPoints[ BLU ].Clear();
    g_iCachedTimerEntity = -1;

    // Cache team_round_timer entities
    int entity           = -1;
    while ( ( entity = FindEntityByClassname( entity, "team_round_timer" ) ) != -1 ) {
        if ( IsValidEntity( entity ) ) {
            g_iCachedTimerEntity = entity;
            break;    // Only need one timer
        }
    }

    // Cache func_respawnroom entities
    entity = -1;
    while ( ( entity = FindEntityByClassname( entity, "func_respawnroom" ) ) != -1 ) {
        if ( IsValidEntity( entity ) ) {
            g_hCachedSpawnRooms.Push( entity );
        }
    }

    // Cache info_player_teamspawn entities
    entity = -1;
    while ( ( entity = FindEntityByClassname( entity, "info_player_teamspawn" ) ) != -1 ) {
        if ( IsValidEntity( entity ) ) {
            int team = GetEntProp( entity, Prop_Send, "m_iTeamNum" );
            if ( team == 2 ) {    // RED
                g_hCachedSpawnPoints[ RED ].Push( entity );
            }
            elif ( team == 3 ) {    // BLU
                g_hCachedSpawnPoints[ BLU ].Push( entity );
            }
        }
    }

    PrintToServer( "[PTE] Entity cache built: %d spawn rooms, %d RED spawns, %d BLU spawns, timer: %d",
                   g_hCachedSpawnRooms.Length, g_hCachedSpawnPoints[ RED ].Length, g_hCachedSpawnPoints[ BLU ].Length, g_iCachedTimerEntity );

    // Analyze spawnpoints for mirror system
    AnalyzeMirrorSpawnpoints();
}

// Analyze spawnpoints for mirror system - determine left/right split based on coordinates
void AnalyzeMirrorSpawnpoints() {
    // Clear existing mirror data
    g_hMirrorSpawnPoints[ RED ][ 0 ].Clear();
    g_hMirrorSpawnPoints[ RED ][ 1 ].Clear();
    g_hMirrorSpawnPoints[ BLU ][ 0 ].Clear();
    g_hMirrorSpawnPoints[ BLU ][ 1 ].Clear();

    // Reset spawnpoint indices
    g_iCurrentSpawnIndex[ RED ][ 0 ] = 0;
    g_iCurrentSpawnIndex[ RED ][ 1 ] = 0;
    g_iCurrentSpawnIndex[ BLU ][ 0 ] = 0;
    g_iCurrentSpawnIndex[ BLU ][ 1 ] = 0;

    int totalSpawns                  = g_hCachedSpawnPoints[ RED ].Length + g_hCachedSpawnPoints[ BLU ].Length;
    if ( totalSpawns < 2 ) {
        g_bMirrorSystemOn = false;
        PrintToServer( "[PTE] Mirror system disabled: insufficient spawnpoints (%d)", totalSpawns );
        return;
    }

    float totalX = 0.0, totalY = 0.0;
    int   count = 0;

    // Calculate average X and Y coordinates from all spawnpoints
    for ( int team = 0; team < 2; team++ ) {
        int spawnCount = g_hCachedSpawnPoints[ team ].Length;
        for ( int j = 0; j < spawnCount; j++ ) {
            int entity = g_hCachedSpawnPoints[ team ].Get( j );
            if ( IsValidEntity( entity ) ) {
                float origin[ 3 ];
                GetEntPropVector( entity, Prop_Data, "m_vecOrigin", origin );
                totalX += origin[ 0 ];
                totalY += origin[ 1 ];
                count++;
            }
        }
    }

    if ( count < 2 ) {
        g_bMirrorSystemOn = false;
        PrintToServer( "[PTE] Mirror system disabled: insufficient valid spawnpoints (%d)", count );
        return;
    }

    // Calculate the middle plane
    g_fMirrorPlaneX = totalX / count;
    g_fMirrorPlaneY = totalY / count;

    // Categorize each spawnpoint as left or right based on the plane
    for ( int team = 0; team < 2; team++ ) {
        int spawnCount = g_hCachedSpawnPoints[ team ].Length;
        for ( int j = 0; j < spawnCount; j++ ) {
            int entity = g_hCachedSpawnPoints[ team ].Get( j );
            if ( IsValidEntity( entity ) ) {
                float origin[ 3 ];
                GetEntPropVector( entity, Prop_Data, "m_vecOrigin", origin );

                // Determine side: spawnpoints with X < planeX are considered "left"
                // We primarily use X coordinate for left/right determination
                int side = ( origin[ 0 ] < g_fMirrorPlaneX ) ? 0 : 1;    // 0 = left, 1 = right

                g_hMirrorSpawnPoints[ team ][ side ].Push( entity );
            }
        }
    }

    g_bMirrorSystemOn = true;
    PrintToServer( "[PTE] Mirror system initialized: plane at (%.1f, %.1f), RED spawns: %d left/%d right, BLU spawns: %d left/%d right",
                   g_fMirrorPlaneX, g_fMirrorPlaneY,
                   g_hMirrorSpawnPoints[ RED ][ 0 ].Length, g_hMirrorSpawnPoints[ RED ][ 1 ].Length,
                   g_hMirrorSpawnPoints[ BLU ][ 0 ].Length, g_hMirrorSpawnPoints[ BLU ][ 1 ].Length );
}

// Validate entity cache
void ValidateEntityCache() {
    bool needsRebuild = false;

    // Check if timer entity is still valid
    if ( g_iCachedTimerEntity != -1 && !IsValidEntity( g_iCachedTimerEntity ) ) {
        needsRebuild = true;
    }

    // Check spawn rooms
    for ( int idx = 0; idx < g_hCachedSpawnRooms.Length; idx++ ) {
        if ( !IsValidEntity( g_hCachedSpawnRooms.Get( idx ) ) ) {
            needsRebuild = true;
            break;
        }
    }

    // Check spawn points
    if ( !needsRebuild ) {
        for ( int team = 0; team < 2; team++ ) {
            for ( int idx = 0; idx < g_hCachedSpawnPoints[ team ].Length; idx++ ) {
                if ( !IsValidEntity( g_hCachedSpawnPoints[ team ].Get( idx ) ) ) {
                    needsRebuild = true;
                    break;
                }
            }
            if ( needsRebuild ) break;
        }
    }

    if ( needsRebuild ) {
        PrintToServer( "[PTE] Entity cache invalidated, rebuilding..." );
        BuildEntityCache();
    }
}

void ApplyDemoResistance( int client ) {
    if ( !IsValidClient( client ) ) return;

    TFClassType playerClass  = TF2_GetPlayerClass( client );
    float       desiredValue = 0.0;
    bool        shouldApply  = false;

    // Determine desired resistance value based on settings and class
    if ( playerClass == TFClass_DemoMan ) {
        if ( !g_bDemoResistEnabled ) {
            // Demo resistance disabled = apply vulnerability (1.25 = 25% more damage)
            desiredValue = 1.25;
            shouldApply  = true;
        } else {
            // Demo resistance enabled = remove attribute (let shield work normally)
            shouldApply = false;
        }
    }

    // Only update if the value has changed (performance optimization)
    if ( shouldApply ) {
        if ( !g_bDemoResistApplied[ client ] || g_fCurrentDemoResistValue[ client ] != desiredValue ) {
            TF2Attrib_SetByName( client, "dmg taken from blast reduced", desiredValue );
            g_fCurrentDemoResistValue[ client ] = desiredValue;
            g_bDemoResistApplied[ client ]      = true;
        }
    } else {
        if ( g_bDemoResistApplied[ client ] ) {
            TF2Attrib_RemoveByName( client, "dmg taken from blast reduced" );
            g_fCurrentDemoResistValue[ client ] = 0.0;
            g_bDemoResistApplied[ client ]      = false;
        }
    }
}

void ClearBootsState( int client ) {
    g_bBootsAttributesApplied[ client ] = false;
    g_fCurrentBootsChargeTurn[ client ] = 0.0;
    g_fCurrentBootsMaxHealth[ client ]  = 0.0;
    g_fCurrentBootsKillRefill[ client ] = 0.0;
    g_fCurrentBootsMoveSpeed[ client ]  = 0.0;
}

void ApplyBootsAttributes( int client ) {
    // Validate client and ensure they're in-game
    if ( !IsValidClient( client ) || !IsPlayerAlive( client ) ) {
        if ( g_bBootsAttributesApplied[ client ] ) ClearBootsState( client );
        return;
    }

    // Check if player is Demoman
    TFClassType playerClass = TF2_GetPlayerClass( client );
    if ( playerClass != TFClass_DemoMan ) {
        if ( g_bBootsAttributesApplied[ client ] ) ClearBootsState( client );
        return;
    }

    // Find Demoman boots (Ali Baba's Wee Booties = 405, Bootlegger = 608)
    int bootsEntity = -1;
    int entity      = -1;

    while ( ( entity = FindEntityByClassname( entity, "tf_wearable" ) ) != -1 ) {
        if ( !IsValidEntity( entity ) ) continue;

        int owner = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
        if ( owner != client ) continue;

        int itemDefIndex = GetEntProp( entity, Prop_Send, "m_iItemDefinitionIndex" );
        if ( itemDefIndex == 405 || itemDefIndex == 608 ) {
            bootsEntity = entity;
            break;
        }
    }

    // If no boots found, clear state and return
    if ( bootsEntity == -1 ) {
        if ( g_bBootsAttributesApplied[ client ] ) ClearBootsState( client );
        return;
    }

    // Get desired attribute values from ConVars
    float chargeTurn  = g_cvBootsChargeTurn.FloatValue;
    float maxHealth   = g_cvBootsMaxHealth.FloatValue;
    float killRefill  = g_cvBootsKillRefill.FloatValue;
    float moveSpeed   = g_cvBootsMoveSpeed.FloatValue;

    // Only update attributes if values have changed or not yet applied
    bool  needsUpdate = false;
    if ( !g_bBootsAttributesApplied[ client ] || g_fCurrentBootsChargeTurn[ client ] != chargeTurn || g_fCurrentBootsMaxHealth[ client ] != maxHealth || g_fCurrentBootsKillRefill[ client ] != killRefill || g_fCurrentBootsMoveSpeed[ client ] != moveSpeed ) {
        needsUpdate = true;
    }

    if ( needsUpdate ) {
        // Apply all attributes to boots entity
        TF2Attrib_SetByName( bootsEntity, "mult charge turn control", chargeTurn );
        TF2Attrib_SetByName( bootsEntity, "max health additive bonus", maxHealth );
        TF2Attrib_SetByName( bootsEntity, "kill refills meter", killRefill );
        TF2Attrib_SetByName( bootsEntity, "move speed bonus shield required", moveSpeed );

        // Update tracking state to prevent redundant updates
        g_fCurrentBootsChargeTurn[ client ] = chargeTurn;
        g_fCurrentBootsMaxHealth[ client ]  = maxHealth;
        g_fCurrentBootsKillRefill[ client ] = killRefill;
        g_fCurrentBootsMoveSpeed[ client ]  = moveSpeed;
        g_bBootsAttributesApplied[ client ] = true;
    }
}

public void OnMapStart() {
    // Rebuild entity cache when map changes
    CreateTimer( 1.0, Timer_DelayedCacheBuild, 0, TIMER_FLAG_NO_MAPCHANGE );
}

// Delayed cache build timer
public Action Timer_DelayedCacheBuild( Handle timer ) {
    BuildEntityCache();
    return Plugin_Stop;
}