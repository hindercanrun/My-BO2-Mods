/****************************************************************************

Level:		Suffer With Me
Location:	Fort Clayton, Panama, North America
Campaign:	1980s

*****************************************************************************/

#include common_scripts\utility;
#include maps\_utility;
#include maps\panama_utility;

main()
{
	// This MUST be first for CreateFX!	
	maps\panama_fx::main();

	level_precache();
	level_init_flags();
	setup_skiptos();

	// Overrides the default introscreen function
	level.custom_introscreen = ::panama_custom_introscreen;

//T6todo	maps\_hiding_door::door_main(); // Run this to enable the hiding_door scripts
//T6todo	maps\_hiding_door::window_main(); // Run this to enable the hiding_window scripts

	maps\_load::main();
	maps\panama_amb::main();
	maps\panama_anim::main();

	// To run the stealth script on the players
	OnPlayerConnect_Callback( ::on_player_connect );

	// Panama fog and post FX
	maps\createart\panama_art::main();

//T6todo	maps\_flare::main(); // Start the _flare() scripts
	maps\_stealth_logic::stealth_init();
	maps\_stealth_behavior::main();
	maps\_swimming::main(); // Enable the swimming feature

//T6todo	maps\_drones::init();

	// Inits vehicle lights
	level._vehicle_load_lights = true;

	SetSavedDvar( "cg_aggressiveCullRadius", "100" );
	SetSavedDvar( "phys_buoyancy", 1 ); // This enables buoyant physics objects in Radiant (our boat)
	SetSavedDvar( "phys_ragdoll_buoyancy", 1 ); // This enables ragdoll corpses to float - Not required, but fun
	SetSavedDvar( "vehicle_riding", 0 );

	level thread setup_global_challenges();
	level thread setup_objectives();
	level thread maps\_objectives::objectives();
	level thread maps\panama_house::panama_wind_settings();

	add_hint_string( "open_grate", &"PANAMA_OPEN_GRATE" );
	add_hint_string( "contextual_kill", &"PANAMA_CONTEXTUAL_KILL" );
	add_hint_string( "street_warning", &"PANAMA_STREET_WARNING" );
	add_hint_string( "hangar_warning", &"PANAMA_HANGAR_WARNING" );	
	add_hint_string( "player_jump_hint", &"PANAMA_PLAYER_JUMP_PROMPT" );
	add_hint_string( "docks_warning", &"PANAMA_DOCKS_WARNING" );

	SetSavedDvar( "vehicle_selfCollision", 0 );
}

// self -> player
on_player_connect()
{
	self thread setup_section_challenges();

	wait 0.15;

	self thread stealth_ai();
}

panama_custom_introscreen( level_prefix, number_of_lines, totaltime, text_color )
{
	introblack = NewHudElem();
	introblack.x = 0;
	introblack.y = 0;
	introblack.horzAlign = "fullscreen";
	introblack.vertAlign = "fullscreen";
	introblack.foreground = true;
	introblack SetShader( "black", 640, 480 );

	flag_wait( "all_players_connected" );

	introblack thread intro_hud_fadeout();

	// Notify intro animation
	flag_wait( "show_introscreen_title" );

	LUINotifyEvent( &"hud_add_title_line", 4, level_prefix, number_of_lines, totaltime, text_color );
	waittill_textures_loaded();

	// The default wait time
	wait 2.5;

	level notify( "introscreen_done" );
}

intro_hud_fadeout()
{
	wait 0.2;

	// Fade out black
	self FadeOverTime( 0.5 ); 
	self.alpha = 0; 

	wait 0.5;

	self Destroy();
}

level_precache()
{
	// Items
	PreCacheItem( "barretm82_emplacement" );
	PreCacheItem( "ac130_vulcan_minigun" );
	PreCacheItem( "ac130_howitzer_minigun" );
	PreCacheItem( "rpg_magic_bullet_sp" );
	PreCacheItem( "rpg_player_sp" );
//T6todo	PreCacheItem( "irstrobe_sp" );
//T6todo	PreCacheItem( "nightingale_sp" );
//T6todo	PreCacheItem( "epipen_sp" );
	PreCacheItem( "ak47_gl_sp" );
	PreCacheItem( "gl_ak47_sp" );
	PreCacheItem( "knife_held_sp" ); // Contextual melee knife
	PreCacheItem( "rpg_sp" );
	PreCacheItem( "m1911_sp" );
	PreCacheItem( "nightingale_dpad_sp" );
	PreCacheItem( "apache_rockets" );

	// Models
	PreCacheModel( "anim_jun_ammo_box" );
	PrecacheModel( "veh_iw_hummer_win_xcam" );
	PreCacheModel( "p6_graffiti_card" );
	PrecacheModel( "p_glo_spray_can" );
	PreCacheModel( "t6_wpn_knife_sog_prop_view" );
	PreCacheModel( "c_usa_woods_panama_casual_viewbody" );
	PreCacheModel( "c_usa_milcas_woods_hair" );
	PreCacheModel( "c_usa_milcas_woods_hair_cap" );
	PreCacheModel( "p6_anim_beer_can" );
	PreCacheModel( "p6_patio_table_teak" );
//T6todo	PreCacheModel( "p6_anim_burlap_sack" );
//T6todo	PreCacheModel( "t6_wpn_molotov_cocktail_prop_world" );
//T6todo	PreCacheModel( "c_usa_woods_panama_lower_dmg1_viewbody" );
//T6todo	PreCacheModel( "c_usa_woods_panama_lower_dmg2_viewbody" );
//T6todo	PreCacheModel( "veh_iw_mh6_littlebird" );
	PreCacheModel( "c_usa_seal80s_skinner_fb" );
//T6todo	PrecacheModel( "p6_anim_hangar_hatch" );
	PreCacheModel( "p6_anim_cloth_pajamas" );
	PreCacheModel( "p6_anim_duffle_bag" );
	PreCacheModel( "c_usa_jungmar_pow_barnes" );
	PreCacheModel( "p6_anim_beer_pack" );
	PreCacheModel( "c_usa_jungmar_barnes_pris_body" );
	PreCacheModel( "c_usa_jungmar_barnes_pris_head" );
	PreCacheModel( "p6_anim_cocaine" );
	PreCacheModel( "t6_wpn_flare_gun_prop" );
	PreCacheModel( "veh_t6_air_private_jet" );
	PreCacheModel( "veh_t6_air_private_jet_dead" );
	PreCacheModel( "c_usa_woods_panama_lower_dmg2_viewbody" );
	PreCacheModel( "t5_weapon_sog_knife_viewmodel" );
	PreCacheModel( "p6_anim_flak_jacket" );

	// Shaders
	PreCacheShader( "cinematic2d" );

	// setting up the mig's bombs through it's vehicle script
//T6todo	maps\_mig17::mig_setup_bombs( "plane_mig23" );
}

setup_skiptos()
{
	// Skipto's - These set up skipto points as well as set up the flow of events in the level.
	// Check _skipto::module_skipto() for more info
	
	// Panama 1
	add_skipto( "house", maps\panama_house::skipto_house, "McKnight's House", maps\panama_house::main );
	add_skipto( "zodiac", maps\panama_airfield::skipto_zodiac, "Zodiac Approach", maps\panama_airfield::zodiac_approach_main );
	add_skipto( "beach", maps\panama_airfield::skipto_beach, "Beach", maps\panama_airfield::beach_main );
	add_skipto( "runway", maps\panama_airfield::skipto_runway, "Runway Standoff", maps\panama_airfield::runway_standoff_main );	
	add_skipto( "learjet", maps\panama_airfield::skipto_learjet, "Lear Jet", maps\panama_airfield::learjet_main );		
	add_skipto( "motel", maps\panama_motel::skipto_motel, "Motel", maps\panama_motel::main );

	// Panama 2
	add_skipto( "slums_intro", ::skipto_panama_2, "Slums Intro" );
	add_skipto( "slums_main", ::skipto_panama_2, "Slums Main" );

	// Panama 3
	add_skipto( "building", ::skipto_panama_3, "Building" );
	add_skipto( "chase", ::skipto_panama_3, "Chase" );
	add_skipto( "checkpoint", ::skipto_panama_3, "Checkpoint" );
	add_skipto( "docks", ::skipto_panama_3, "Docks" );
	add_skipto( "sniper", ::skipto_panama_3, "Sniper" );

	default_skipto( "house" );

	set_skipto_cleanup_func( maps\panama_utility::skipto_setup );
}

skipto_panama_2()
{
	ChangeLevel( "panama_2", true );
}

skipto_panama_3()
{
	ChangeLevel( "panama_3", true );
}

/* ------------------------------------------------------------------------------------------
CHALLENGES
-------------------------------------------------------------------------------------------*/
setup_section_challenges() // self -> player
{
	self thread maps\_challenges_sp::register_challenge( "thinkfast", maps\panama_airfield::challenge_thinkfast );
	self thread maps\_challenges_sp::register_challenge( "flak_jacket", maps\panama_airfield::challenge_kill_ai_with_flak_jacket );
//T6todo	self thread maps\_challenges_sp::register_challenge( "nightingale", maps\panama_airfield::challenge_nightingale );
//T6todo	self thread maps\_challenges_sp::register_challenge( "hangardoors", maps\panama_airfield::challenge_close_hangar_doors );
	self thread maps\_challenges_sp::register_challenge( "destroylearjet", maps\panama_airfield::challenge_destroy_learjet );
	self thread maps\_challenges_sp::register_challenge( "turretkill", maps\panama_airfield::challenge_turret_kill );
}