#include maps\_utility;
#include common_scripts\utility;
#include maps\war_room_util;
#include maps\frontend_util;
#include maps\_music;

//RTAtodo #insert raw\common_scripts\utility.gsh;
//RTAtodo #insert raw\maps\frontend.gsh;

#define CLIENT_FLAG_CLOCK			12
#define CLIENT_FLAG_MAP_MONITOR		13

// Defintions in frontend.gsh
#define TERRITORY_IRAN				2
#define TERRITORY_AFGHANISTAN		0
#define TERRITORY_INDIA				1
#define TERRITORY_RUSSIA			4

main()
{	
	//This MUST be first for CreateFX!
	maps\frontend_fx::main();

	frontend_precache();
	
	maps\_load::main();
	maps\frontend_amb::main();
	maps\frontend_anim::main();
	maps\_patrol::patrol_init();

	level thread maps\createart\frontend_art::main();
	
	frontend_init_common();
	frontend_flag_init();
	setup_objectives();

	fade_out(0);
	hide_holo_table_props();
	
	// show it so we can hide it on boot :-P.
	show_holotable_fuzz( true );
	
	level thread watch_for_lockout_screen();
	level thread frontend_run_scene();
	level thread frontend_watch_resume();
	
	wait_for_first_player();
	
	level thread level_player_init();
}

setup_objectives()
{
	level.OBJ_WAR_ROOM = register_objective( &"FRONTEND_REPORT_TO_WAR_ROOM" );
	level thread maps\_objectives::objectives();
}

frontend_flag_init()
{
	flag_init( "lockout_screen_passed" );
	flag_init( "bootup_sequence_done_first_time" );
	flag_init( "lockout_screen_skipped" );
	flag_init( "lockout_screen_skipped_freeroam"  );
	flag_init( "strikeforce_stats_loaded" );
	flag_init( "frontend_scene_ready" );
	flag_init( "briefing_active" );
}

frontend_precache()
{
//	PrecacheShader( "logo_cod2" );
	PreCacheShader("webm_720p");
	
	PrecacheModel( "p6_anim_sf_tablet" );
	
	PrecacheModel( "p6_hologram_so_base_map" );
	PrecacheModel( "p6_hologram_so_target_bldg_01" );
	PrecacheModel( "p6_hologram_so_target_bldg_02" );
	PrecacheModel( "p6_hologram_so_target_bldg_03" );
	PrecacheModel( "p6_hologram_so_target_bldg_04" );
	PrecacheModel( "p6_hologram_so_target_bldg_05" );
	PrecacheModel( "p6_hologram_so_target_rock_01" );
	PrecacheModel( "p6_hologram_so_enter_path" );
	PrecacheModel( "p6_hologram_so_exit_path" );
	PrecacheModel( "p6_anim_hologram_vtol_combined" );
	
	PrecacheModel( "p6_anim_resume" );
	PreCacheModel("p6_sunglasses");
	
	PrecacheModel( "p6_hologram_av_combined" );
	PrecacheModel( "p6_hologram_av2_combined" );
	PrecacheModel( "p6_hologram_hack_device" );
	PrecacheModel( "p6_hologram_missile" );

	//afghanistan models
	PrecacheModel("p6_hologram_af_base_map");
	PrecacheModel("p6_hologram_af_path_arrow");
	PrecacheModel("p6_hologram_quadrotor_combined");
	PrecacheModel("p6_hologram_vtol_combined");
	PrecacheModel("p6_hologram_asd_combined");
	PrecacheModel("p6_hologram_cougar_combined");
	
	// pak
	PrecacheModel("p6_hologram_zhao_bust");
	PrecacheModel("p6_hologram_zhao_text_01");
	PrecacheModel("p6_hologram_zhao_text_02");
	PrecacheModel("p6_hologram_world_map_globe");
	PrecacheModel("p6_hologram_dr_base_map");
	PrecacheModel("p6_hologram_dr_computer");
	PrecacheModel("p6_hologram_dr_dish");
	PrecacheModel("p6_hologram_dr_roof");
	PrecacheModel("p6_hologram_dr_tank");
	PrecacheModel("p6_hologram_dr_transformer");
	
	PrecacheModel( "c_usa_cia_frnd_viewbody_vson" );
	PrecacheModel( "c_usa_cia_masonjr_viewbody_vson_ui3d" );
	PrecacheModel( "c_usa_cia_frnd_viewbody_vsoff" );

	PreCacheString( &"frontend_screen" );
	PreCacheString( &"toggle_glasses" );
	PreCacheString( &"start_credits" );
	PreCacheString( &"stop_credits" );
	PreCacheString( &"frontend_restore" );
	PreCacheString( &"frontend_restore2" );
	PreCacheString( &"leave_campaign2" );
	PreCacheString( &"intro_complete");
	PreCacheString( &"frontend_player_connected" );
	PrecacheString( &"show_skip_prompt" );
	PrecacheString( &"cm_activate" );
	
	// Necessary for communicating with LUI
	PreCacheMenu( "lockout" );
	PreCacheMenu( "menu_close" );
	PreCacheMenu( "campaign_state" );
	PreCacheMenu( "luisystem" );
	PreCacheMenu( "launchlevel" );
}

do_stats()
{
	flag_wait_any( "lockout_screen_passed", "lockout_screen_skipped", "lockout_screen_skipped_freeroam" );
	
	if( GetDvar( "ui_aarmapname" ) != "" )
	{
		level thread maps\_endmission::check_for_achievements_frontend( GetDvar( "ui_aarmapname" ) );
	}
}

level_player_init()
{	
	on_player_connect();
	
	level.player FreezeControls(true);
	wait_network_frame();

	//-- Short delay to get player in position
	wait_network_frame();
	
	setFirstMusicState();
	
	level thread do_stats();
	
	if ( frontend_just_finished_rts() )
	{
		SetDvarInt("ui_dofrontendsave",1);//rts returns always trigger a save, because a quit still counts
		level thread turn_on_glasses( false );
	}
	else
	{
		level thread turn_on_glasses( true );
	}
	
	level.player thread listen_for_campaign_state_change();
	level.player thread listen_for_luisystem_messages();
	level.player thread listen_for_launchlevel_messages();
	
	//level delay_thread( 2.0, ::turn_on_glasses );
	
	VisionSetNaked( "sp_frontend_bridge", 0.0 );
	
	frontend_do_save();
	load_gump( "frontend_gump_sf_a" );
	
	/#
	frontend_setup_devgui();
	#/
}

setFirstMusicState()
{
	if( !flag("lockout_screen_skipped") && !flag("lockout_screen_skipped_freeroam") && !flag("lockout_screen_passed"))
	{
		setmusicstate( "FRONT_END_START" );
	}
	else
	{
		setmusicstate( "FRONT_END_MAIN" );
	}
}

// Initialization for the 
frontend_init_common()
{
	// Allows the HUD to show during scenes.
	get_level_era();
	
	holo_table_system_init();
	
	level.e_player_align = GetEnt( "player_align_node", "targetname" );

	level.m_rts_warmap_offset = [];
	level.m_rts_warmap_offset["so_rts_mp_dockside"]		= ( 0.0, -0.3, 1.0 );
	level.m_rts_warmap_offset["so_rts_afghanistan"]		= ( 0.0, -0.3, 1.0 );
	level.m_rts_warmap_offset["so_rts_mp_drone"]		= ( 0.0, -0.3, 1.0 );
	
	// Disputed territories associated with levels.
	level.m_rts_territory = [];
	level.m_rts_territory["so_rts_mp_dockside"]	= "iran";
	level.m_rts_territory["so_rts_afghanistan"]	= "afghanistan";
	level.m_rts_territory["so_rts_mp_drone"]	= "india";
	
	level.m_rts_map_id = [];
	level.m_rts_map_id["so_rts_mp_dockside"]	= TERRITORY_IRAN;
	level.m_rts_map_id["so_rts_afghanistan"]	= TERRITORY_AFGHANISTAN;
	level.m_rts_map_id["so_rts_mp_drone"]		= TERRITORY_INDIA;
	
	level.m_rts_city_tag = [];
	level.m_rts_city_tag["so_rts_mp_dockside"] = "tag_fx_keppel";
	level.m_rts_city_tag["so_rts_afghanistan"] = "tag_fx_kabul";
	level.m_rts_city_tag["so_rts_mp_drone"] = "tag_fx_pradesh";
	level.m_rts_city_tag["so_rts_mp_socotra"] = "tag_fx_socotra";
	level.m_rts_city_tag["so_rts_mp_overflow"] = "tag_fx_pakistan";

	// Objectives.
	add_global_spawn_function( "axis", ::no_grenade_bag_drop );
	
	trigger_off( "table_interact_trigger" );
	
	table_trig = GetEnt( "table_interact_trigger", "targetname" );
	table_trig SetHintString( &"FRONTEND_USE_STRIKEFORCE" );
	
	level.m_drone_collision = GetEntArray( "drone_collision", "targetname" );
	
	level thread frontend_init_shaders();
	
	globe = build_globe();
	float_pos = GetEnt( "holo_table_floating", "targetname" );
	globe.origin = float_pos.origin;
}

frontend_init_shaders()
{
	// Wait for the player so we know the client script is running.
	wait_for_first_player();
	
	clock_list = GetEntArray( "world_clock", "targetname" );
	foreach( clock in clock_list )
	{
		clock IgnoreCheapEntityFlag( true );
		clock SetClientFlag( CLIENT_FLAG_CLOCK );
	}
	
	monitor_list = GetEntArray( "world_map", "targetname" );
	foreach( monitor in monitor_list )
	{
		monitor IgnoreCheapEntityFlag( true );

		monitor SetClientFlag( CLIENT_FLAG_MAP_MONITOR );
	}
	
	wait_network_frame();
	
	refresh_war_map_shader();
}


on_player_connect()
{
	// Have to delay to disable weapons.	
	wait_network_frame();
	
	LUINotifyEvent(&"frontend_player_connected");
	
	level.player TakeAllWeapons();
	level.player DisableWeapons();
	level.player AllowPickupWeapons( false );
	level.player AllowSprint( false );
	level.player AllowJump( false );
	
	level.player init_viewarm();
	
	level.m_rts_stats = [];
	level.m_rts_stats["so_rts_mp_dockside"]		= "SO_WAR_SINGAPORE_SUCCESS";
	level.m_rts_stats["so_rts_afghanistan"]		= "SO_WAR_AFGHANISTAN_SUCCESS";
	level.m_rts_stats["so_rts_mp_drone"]		= "SO_WAR_DRONE_SUCCESS";
	level.m_rts_stats["so_rts_mp_socotra"]		= "SO_WAR_SOCOTRA_SUCCESS";
	level.m_rts_stats["so_rts_mp_overflow"]		= "SO_WAR_PAKISTAN_SUCCESS";
	
	level.m_phase_stats[1] = "SO_WAR_HUB_ONE_INTRO";
	level.m_phase_stats[2] = "SO_WAR_HUB_TWO_INTRO";
	level.m_phase_stats[3] = "SO_WAR_HUB_THREE_INTRO";
	level.m_phase_stats[4] = "SO_WAR_PAKISTAN_INTRO";
	
	flag_set( "strikeforce_stats_loaded" );
}

no_grenade_bag_drop()
{
	// every axis resets this value when spawned, am forcing this here
	level.nextGrenadeDrop	= 100000;	// no grenade bag drop!	
}
