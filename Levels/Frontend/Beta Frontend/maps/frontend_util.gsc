/*
 * Created by ScriptDevelop.
 * User: mslone
 * Date: 4/10/2012
 * Time: 6:11 PM
 * 
 * To change this template use Tools | Options | Coding | Edit Standard Headers.
 */

#include maps\_dialog;
#include maps\_objectives;
#include maps\_scene;
#include maps\_utility;
#include maps\_endmission;
#include common_scripts\utility;
#include maps\war_room_util;
#include maps\_music;

//RTAtodo #insert raw\common_scripts\utility.gsh;
//RTAtodo #insert raw\maps\level_progression.gsh;
//RTAtodo #insert raw\maps\frontend.gsh;

#define HOLO_TABLE_EXPLODER		(111)
	
#define Default_Near_Start 0
#define Default_Near_End 1
#define Default_Far_Start 8000
#define Default_Far_End 10000
#define Default_Near_Blur 6
#define Default_Far_Blur 0

#define MENUSTATE_DISABLED		-1
#define MENUSTATE_NONE			0
#define MENUSTATE_MAIN			1
#define MENUSTATE_SECRET		2
#define MENUSTATE_STRIKEFORCE	3
#define MENUSTATE_LOCKOUT		4
#define MENUSTATE_CREDITS		5
	
#define CLIENT_FLAG_HOLO_RED		14
#define CLIENT_FLAG_HOLO_VISIBLE	15
	
// Vehicle flags.
#define CLIENT_FLAG_SPEEDING_OSPREY 11


// Defintions in level_progression.gsh
#define LEVEL_PROGRESSION_CSV			"sp/levelLookup.csv"
#define LEVEL_PROGRESSION_LEVEL_NAME	1
#define LEVEL_PROGRESSION_LEVEL_INDEX	0
#define LEVEL_PROGRESSION_MAPTYPE		8
#define LEVEL_PROGRESSION_RTSEND		14
#define LEVEL_PROGRESSION_RTSHUB		17

// Defintions in 
#define TINT_UNAVAILABLE				4
#define TINT_CLEARED					3
#define TINT_FAILED						2
#define TINT_AVAILABLE					0

// Defintions in frontend.gsh
#define TERRITORY_IRAN				2
#define TERRITORY_AFGHANISTAN		0
#define TERRITORY_INDIA				1
#define TERRITORY_RUSSIA			4

//this is the function that handles selecting the setting and placing the player - actions that start briefings and debriefings happen elsewhere
setup_basic_scene()
{	
	ambient_scene_list = [];
	for ( i = 1; i <= 5; i++ )
		ambient_scene_list[ambient_scene_list.size] = "ambient_0" + i;
	
	// Set up the ambient scene and attach collision to the actors.
	if ( !isdefined( level.m_bridge_workers ) )
	{
		level.m_bridge_workers = [];
		
		num_worker_scenes = 3;
		if ( RandomFloat( 2.0 ) <= 1.0 )
			num_worker_scenes = 4;
			
		for ( i = 0; i < num_worker_scenes; i++ )
		{
			ambient_scene = random( ambient_scene_list );
			ArrayRemoveValue( ambient_scene_list, ambient_scene );
	
			level thread run_scene( ambient_scene );
			drone_list = get_model_or_models_from_scene( ambient_scene );			
			level.m_bridge_workers = ArrayCombine( level.m_bridge_workers, drone_list, true, false );
		}
	}
	
	level_num = get_level_number_completed();
	
	// Set up the mission team in the briefing room.
	setup_war_map( level_num + 1 );
	level_list = get_strikeforce_available_level_list(level_num + 1);
	if ( get_campaign_state() != 0 && (level_list.size != 0 || frontend_just_finished_rts()) )
	{
		// Put Briggs in the mission briefing room.
		level thread run_scene( "sf_briggs_idle" );
	}
	
	use_vtol = frontend_should_use_vtol( level_num + 1 );
	if ( use_vtol )
	{
		if( !IsDefined( level.vtol_scene_running ) )
		{
			level thread run_scene( "vtol_ambient_00" );
			level.vtol_scene_running = true;
		}
				
		warp_to_player_start( "vtol_player_start" );
		frontend_run_ospreys();
		
		if (level.menuState==MENUSTATE_NONE)
		{
			level.menuState=MENUSTATE_MAIN;
			toggle_main_menu();
		}
	}
	else if ( get_campaign_state() == 0 || level_num == 0 )
	{
		warp_to_player_start();
	}
	else
	{
		warp_to_random_player_start();
	}
	
	// if the glove was already up, run the scene again to update the positioning.
	if ( is_true( level.player.is_glove_shown ) )
	{
		player_body = GetEnt( "player_body", "targetname" );
		old_blend_time = 0.1;
		if ( isdefined( player_body ) )
		{
			old_blend_time = player_body._anim_blend_in_time;
			player_body maps\_anim::anim_set_blend_in_time( 0.1 );
		}
		end_scene("data_glove_idle");
		wait_network_frame();
		level thread run_scene( "data_glove_idle" );
		
		wait 0.1;
		
		if ( isdefined( player_body ) )
		{
			player_body maps\_anim::anim_set_blend_in_time( old_blend_time );
		}
	}
	
	wait_network_frame();
	
	// Show the glowbb
	show_globe( true, false, true );
	show_holotable_fuzz( false );
	
	if ( get_campaign_state() != 0 )
	{
		if ( frontend_just_finished_rts() )
		{
			level thread frontend_rts_level_respond();
		}
	}
}


frontend_rts_level_respond()
{
	run_scene_first_frame( "player_look_at_war_map" );
	level thread run_scene( "sf_briggs_idle" );
	
	flag_wait( "strikeforce_stats_loaded" );
	
	last_level = get_level_number_completed();
	cur_level = last_level + 1;
	map_list = get_strikeforce_available_level_list(cur_level);

	last_map = GetDvar( "ui_aarmapname" );
	
	success = rts_map_completed( last_map );
	color_id = 2;			// red!
	if ( success )
		color_id = 3;		// green!
	
	warmap_offset = level.m_rts_warmap_offset[last_map];
	map_id = level.m_rts_map_id[last_map];
	
	if ( isdefined( map_id ) )
	{
		set_world_map_marker( map_id, true );
		set_world_map_widget( map_id, false );
		level thread war_map_blink_country( map_id, color_id, "stop_war_blink" );
	}

	if ( isdefined( warmap_offset ) )
	{
		world_map_zoom_to( warmap_offset[0], warmap_offset[1], warmap_offset[2] );
	}
	
	positive_lines = array(
		"brig_nice_work_mason_0",
		"brig_i_knew_i_could_rely_0",
		"brig_hell_of_a_job_there_0",
		"brig_that_s_what_i_like_t_0",
		"brig_that_s_how_we_get_sh_0",
		"brig_that_was_one_for_the_0" );
	negative_lines = array(
		"brig_what_the_fuck_was_th_0",
		"brig_i_ve_never_seen_such_0",
		"brig_that_was_a_full_scal_0",
		"brig_what_the_hell_went_w_0",
		"brig_we_ll_talk_about_thi_0",
		"brig_i_m_disappointed_and_0" );
	
	response_line = undefined;
	if ( success )
	{
		response_line = random( positive_lines );
	} else {
		response_line = random( negative_lines );
	}
	
	if ( isdefined( response_line ) )
		level.player thread say_dialog( response_line, 2.0 );
	
	// Scene of briggs telling you're either awesome or lame.
	wait 2.0;
	run_scene( "player_look_at_war_map" );
	level notify( "stop_war_blink" );
	if ( isdefined( map_id ) )
	{
		set_world_map_marker( map_id, false );
		if ( !success )
			set_world_map_widget( map_id, true );
	}
	
	world_map_zoom_to( 0.0, 0.0, 1.0 );
	
	toggle_main_menu();
}

hide_holo_table_props()
{
	props = GetEntArray( "holo_table_prop", "script_noteworthy" );
	foreach( prop in props )
	{
		prop Hide();
	}
}

frontend_do_save(force=false)
{
	if (force || GetDvarInt("ui_skipmainlockout") != 0)
	{
		stats_only = !force && !GetDvarInt( "ui_dofrontendsave" );
		//this will force it to always overwrite the stats part of the save file
		//and optionally update the save itself (only when ui_dofrontendsave is true)
		SaveGame( "auto", stats_only ) ;
		level waittill("savegame_done");
	}
	SetDvarInt( "ui_dofrontendsave", 0 );
}

frontend_just_finished_rts()
{
	str_prev_level = GetDvar( "ui_aarmapname" );
	if ( !isdefined( str_prev_level ) )
	{
		return false;
	}
	
	return IsSubStr( str_prev_level, "so_rts" );
}

rts_map_completed( str_map_name )
{
	str_stat_name = level.m_rts_stats[ str_map_name ];
	assert( isdefined( str_stat_name ) );
	stat_val = level.player get_story_stat( str_stat_name );
	return stat_val != 0;
}

warp_to_random_player_start()
{
	start_list = array( "player_start_01", "player_start_02", "player_start_03", "player_start_04" );
	warp_to_player_start( random( start_list ) );
}

warp_to_player_start( warp_targetname = "default_player_start" )
{
	s_warp = GetStruct( warp_targetname );
	skipto_teleport_players( warp_targetname );
	
	wait_network_frame();
	
	level.player.origin = s_warp.origin;
//RTAtodo	level.player.angles = FLAT_ANGLES( s_warp.angles );
	level.player.angles = ( s_warp.angles[0], s_warp.angles[1], 0 );
	
	level.e_player_align.origin = s_warp.origin;
//RTAtodo	level.e_player_align.angles = FLAT_ANGLES( s_warp.angles );
	level.e_player_align.angles = ( s_warp.angles[0], s_warp.angles[1], 0 );
}

get_level_number_completed()
{
	return level.player GetDStat( "PlayerStatsList", "HIGHESTLEVELCOMPLETED", "statValue" );
}

start_patrollers()
{
	patrollers = simple_spawn( "idle_patroller" );
	foreach ( ai in patrollers )
	{
		ai.disable_melee = true;
		ai thread maps\_patrol::patrol( ai.target );
	}
}

init_viewarm()
{	
	self.is_glove_shown = false;
	//toggle_viewarm( true );
}

data_glove_input_Button()
{
	pressed = false;

	if ( !level.console && !level.player GamepadUsedLast() )
	{
		pressed = level.player ButtonPressed("MOUSE1") || level.player ButtonPressed("ESCAPE") || level.player ButtonPressed("ENTER");
	}
	else
	{
		pressed = level.player ButtonPressed("BUTTON_A") || level.player ButtonPressed("BUTTON_B") || level.player ButtonPressed("BUTTON_X") || level.player ButtonPressed("BUTTON_Y");
	}

	return pressed;
}

data_glove_input()
{
	self endon( "menu_closed" );
	while ( true )
	{
		if ( data_glove_input_Button() )
		{
			run_scene( "data_glove_input" );
			
			while ( data_glove_input_Button() )
			{
				wait_network_frame();
			}
		}
		wait_network_frame();
	}
}

// 0 or 1 means this is our last chance.
// -1 means our chance has passed.
//
strikeforce_get_num_levels_till_gone( campaign_level_num, rts_level_name )
{
	end_level = int ( TableLookup(LEVEL_PROGRESSION_CSV,LEVEL_PROGRESSION_LEVEL_NAME,rts_level_name,LEVEL_PROGRESSION_RTSEND) );
	if ( campaign_level_num >= end_level )
		return -1;
	
	cur_level_type = "";
	chances_remaining = 0;
	for ( cur_level = campaign_level_num; cur_level < end_level; cur_level++ )
	{
		cur_level_type = TableLookup(LEVEL_PROGRESSION_CSV,LEVEL_PROGRESSION_LEVEL_INDEX,cur_level,LEVEL_PROGRESSION_MAPTYPE);
		if ( cur_level_type == "CMP" )
			chances_remaining++;
		else if ( cur_level_type == "RTS" )
			break;
	}
	
	return chances_remaining;
}

frontend_should_use_vtol( cur_level )
{
	blackout_level_num = Int( TableLookup(LEVEL_PROGRESSION_CSV,LEVEL_PROGRESSION_LEVEL_NAME,"blackout",LEVEL_PROGRESSION_LEVEL_INDEX) );
	return cur_level > blackout_level_num;
}

get_campaign_state()
{
	campaign_state = GetDvarInt( "ui_campaignstate" );
	
	return campaign_state;
}

//polling for the right trigger input
//

stop_credits_button()
{
	pressed = false;
	
	if ( !level.console && !level.player GamepadUsedLast() )
	{
		pressed = level.player ButtonPressed( "MOUSE1" );
	}
	else
	{
		pressed = level.player ButtonPressed( "BUTTON_A" );
	}

	return pressed;
}
run_glasses_input()
{
	level endon( "disconnect" );

	while( 1 )
	{
		if (!IsDefined(level.luiModal) || level.luiModal==false)
		{
			switch (level.menuState)
			{
			case MENUSTATE_NONE:
				break;
			case MENUSTATE_MAIN:
				break;
			case MENUSTATE_SECRET:
				//do_secret_menu() is a blocking call - really no need to ever set menustate_secret, it's just included for completeness
				break;
			case MENUSTATE_STRIKEFORCE:
				//strikeforce state is set and cleared elsewhere
				break;
			case MENUSTATE_LOCKOUT:
				//not really possible, but for completeness
				break;
			case MENUSTATE_CREDITS:
				if ( stop_credits_button() )
				{
					level notify( "credits_abort" );
					LUINotifyEvent( &"stop_credits" );
					level.menuState=MENUSTATE_MAIN;
					toggle_main_menu();
				}
				break;
			}
		}
		wait(0.05);
	}
}

scene_glasses_on()
{
	level run_scene_first_frame("glasses_on");
	
	flag_wait_any( "lockout_screen_passed", "lockout_screen_skipped", "lockout_screen_skipped_freeroam" );
	
	level thread run_scene("glasses_on");
	
	wait_network_frame();
	
	//-- help the glasses clip the screen closer to the camera
	glasses = get_model_or_models_from_scene("glasses_on", "glasses");
	glasses setviewmodelrenderflag( true );
}

turn_on_glasses( glasses_on = true )
{
	level endon( "disconnect" );
	
	flag_wait( "frontend_scene_ready" );
	
	level.e_player_align.origin = level.player.origin;
	level.e_player_align.angles = FLAT_ANGLES( level.player.angles );
	
	if ( !flag( "lockout_screen_skipped" ) && !flag(  "lockout_screen_skipped_freeroam"  ))
	{
		level thread scene_glasses_on();
	}
		
	level thread control_vision_set_glasses();
		
	//-- play the put on glasses animation after the lockout screen is passed
	flag_wait_any( "lockout_screen_passed", "lockout_screen_skipped",  "lockout_screen_skipped_freeroam" );
	
	if ( !flag( "lockout_screen_skipped" ) && !flag( "lockout_screen_skipped_freeroam" ))
	{
		wait(1.0);
		//-- play bootup
		flag_wait("headsupdisplay");
		wait(0.5);
		level.player SetBlur( 1.6, 2.5 );
		maps\_glasses::play_bootup();
    }
	
	skipanim = GetDvar( "ui_aarmapname" ) != "";
	
	if ( !flag(  "lockout_screen_skipped_freeroam"  ))
		level.player toggle_viewarm( true, skipanim );
	
//	maps\createart\frontend_art::dof_frontend();

	level thread run_glasses_input();
}

attach_data_glove()
{
	if ( !is_true( self.m_data_glove_attached ) )
	{
		self SetViewModelRenderFlag( true );
		self Attach( "c_usa_cia_frnd_viewbody_vson", "J_WristTwist_LE" );
		self.m_data_glove_attached = true;
	}
	
	if ( is_true( self.glove_fx_on ) )
	{
		if ( flag( "briefing_active" )  )
		{
			self notify( "stop_glove_fx" );
			self.glove_fx_on = false;
		}
	}
	else if ( flag( "briefing_active" ) )
	{
		self play_fx( "data_glove_glow", undefined, undefined, "stop_glove_fx", true, "J_WristTwist_LE" );
		self.glove_fx_on = true;
	}
}

attach_data_pads()
{
	drone_names = array( "troop_01_drone", "troop_02_drone" );
	foreach( name in drone_names )
	{
		drone = GetEnt( name, "targetname" );
		if ( isdefined( drone ) )
		{
			if ( !is_true( drone.has_tablet ) )
			{
				drone Attach( "p6_anim_sf_tablet", "tag_weapon_left", true );
				drone.has_tablet = true;
			}
		}
	}
}

toggle_viewarm( do_show, skipanim = false )
{
	// If the glove hasn't been inited yet, don't try to toggle it.
	if ( !isdefined( self.is_glove_shown ) )
	{
		return;
	}
	
	if ( !IsDefined( do_show ) )
	{
		do_show = !self.is_glove_shown;
	}
	
	if ( self.is_glove_shown == do_show )
	{
		return;
	}
	
	level_num = get_level_number_completed();
	use_vtol = frontend_should_use_vtol( level_num + 1 );
	
	// self SetLowReady( !do_show );
	if ( do_show )
	{
		if( use_vtol )
		{
			VisionSetNaked( "sp_front_end_menu_vtol", 1.0 );
		}
		else
		{
			VisionSetNaked( "sp_front_end_menu", 1.0 );
		}
		
		// Move the align node to the player's feet so the view is flat.
		level.e_player_align.origin = level.player.origin;
		level.e_player_align.angles = FLAT_ANGLES( level.player.angles );
		
		level.player SetBlur( 1.6, 2.5 );
		
		// When game is first loaded.
		if ( !skipanim )
		{
			level thread run_scene( "data_glove_start" );
		
			wait_network_frame();
			player_body = get_model_or_models_from_scene( "data_glove_start", "player_body" );
			player_body attach_data_glove();
			
			scene_wait( "data_glove_start" );
			
			end_scene("data_glove_idle");
			wait_network_frame();
			level thread run_scene( "data_glove_idle" );
			
		// Returning from a played level.
		} else {
			end_scene("data_glove_idle");
			wait_network_frame();
			level thread run_scene( "data_glove_idle" );
			
			wait_network_frame();
			player_body = get_model_or_models_from_scene( "data_glove_idle", "player_body" );
			player_body attach_data_glove();
		}
		
		level.player thread data_glove_input();
	} 
	else
	{
		VisionSetNaked( "sp_frontend_bridge", 1.0 );
		level.player notify( "menu_closed" );
		run_scene( "data_glove_finish" );
		level.player SetBlur( 0, 0.5 );
	}
	
	self.is_glove_shown = do_show;
}

toggle_main_menu()
{
	//show/hide the main menu
	LUINotifyEvent( &"toggle_glasses" );
	wait_network_frame();
	level.player toggle_viewarm();
}

control_vision_set_glasses()
{
	flag_wait("glasses_tint");

	level.player VisionSetNaked( "sp_front_end_glasses_up", 0.05);
	wait(0.15);
	level.player VisionSetNaked( "sp_frontend_bridge", 2.0);
}

watch_for_lockout_screen()
{
	flag_wait( "level.player" );
	
	while( true )
	{
		level.player waittill("menuresponse", str_menu_action, str_action_arg);
		
		if(str_menu_action == "lockout")
		{
			switch(str_action_arg)
			{
			case "activated":
				level.menuState=MENUSTATE_LOCKOUT;
				level notify( "frontend_refresh_scene" );
				level clientnotify( "sndNOAMB" );
				setmusicstate("FRONT_END_START");
				break;
			case "deactivated":
				flag_set( "bootup_sequence_done_first_time");
				level.menuState=MENUSTATE_MAIN;
				level clientnotify( "sndAMB" );
				setmusicstate("FRONT_END_MAIN");
				break;
			case "skipped":
				level notify( "frontend_refresh_scene" );
				flag_set( "lockout_screen_skipped" );
				level.menuState=MENUSTATE_MAIN;
				level clientnotify( "sndAMB" );
				setmusicstate("FRONT_END_MAIN");
				break;
			case "skipped_freeroam":
				level notify( "frontend_refresh_scene" );
				flag_set( "lockout_screen_skipped_freeroam" );
				level.menuState=MENUSTATE_NONE;
				level clientnotify( "sndAMB" );
				setmusicstate("FRONT_END_MAIN");
				break;
			case "need_glasses":
				level notify( "frontend_refresh_scene" );
				flag_set( "lockout_screen_passed");
				level.menuState=MENUSTATE_DISABLED;
				level clientnotify( "sndAMB" );
				setmusicstate("FRONT_END_MAIN");
				break;
			case "glasses_boot_complete":
				level clientnotify( "sndAMB" );
				setmusicstate("FRONT_END_MAIN");
				break;
			case "start_credits":
				level notify( "frontend_refresh_scene" );
				flag_set( "lockout_screen_skipped_freeroam" );
				level.menuState=MENUSTATE_CREDITS;
				level clientnotify( "sndAMB" );
				setmusicstate("CREDITS");
				//TODO:  may need a version that plays without movies if we want to have in the options menu, and not just at game completion
				level thread credits_scroll_with_movies_sequence();
				break;
			}
		}
	}
}

listen_for_luisystem_messages()
{
	while (true)
	{
		self waittill("menuresponse",str_menu_action, str_action_arg );
		if (str_menu_action=="luisystem")
		{
			switch(str_action_arg)
			{
			case "modal_start":
				level.luiModal=true;
				break;
			case "modal_stop":
				level.luiModal=false;
				break;
			case "cm_start":
				level thread cm_input_watcher();
				break;
			case "cm_stop":
				level notify("terminate_cm_watcher");
				break;
			}
		}
	}
}


play_phase_intro()
{
	last_level = get_level_number_completed();
	hub_num = frontend_get_hub_number( last_level + 1 );
	
	switch( hub_num )
	{
		case 1:
			if (level.player get_story_stat( "SO_WAR_HUB_ONE_INTRO" ) != 0)
				return ;
			maps\frontend_sf_a::scene_pre_briefing();
			break;
		case 2:
			if (level.player get_story_stat( "SO_WAR_HUB_TWO_INTRO" ) != 0)
				return ;
			maps\frontend_sf_b::scene_pre_briefing();
			break;
		case 3:
			if (level.player get_story_stat( "SO_WAR_HUB_THREE_INTRO" ) != 0)
				return ;
			maps\frontend_sf_c::scene_pre_briefing();
			break;
		case 4:
			maps\frontend_sf_c::scene_pre_briefing_phase4();
			break;
	}
}

briefing_fade_up()
{
	setmusicstate("MUS_FE_STRIKEFORCE");
	wait 0.5;
	attach_data_pads();
	fade_in( 0.5 );
}

listen_for_launchlevel_messages()
{
	while (true)
	{
		self waittill("menuresponse",str_menu_action, str_action_arg );
		if (str_menu_action=="launchlevel")
		{
			get_players()[0] strikeforce_decrement_unit_tokens();
			fade_out(0.5);
			toggle_main_menu();
			level thread maps\createart\frontend_art::run_war_room_mixers();
			flag_set( "briefing_active" );
			
			//the player might be launching the tutorial level, if so then the action arg is wrong and we should use the ui_aarmapname dvar
			//because that is set correctly to the ultimate target prior to this notification call
			if (str_action_arg=="so_tut_mp_drone")
				level_for_briefing=GetDvar("ui_aarmapname");
			else
				level_for_briefing=str_action_arg;

			//look at the level being launched, play animations and other stuff if desired 
			show_holotable_fuzz( true );
			show_globe( false, true );
			holo_table_exploder_switch( 117 );
			
			level thread frontend_watch_scene_skip( str_action_arg );

			//set the "I've launched this level once" flag
			switch(level_for_briefing)
			{
			case "so_rts_mp_dockside":
				level.player set_story_stat( "SO_WAR_SINGAPORE_INTRO", true );
				break;
			case "so_rts_mp_drone":
				level.player set_story_stat( "SO_WAR_DRONE_INTRO", true );
				break;
			case "so_rts_mp_overflow":
				level.player set_story_stat( "SO_WAR_PAKISTAN_INTRO", true );
				break;
			case "so_rts_mp_socotra":
				level.player set_story_stat( "SO_WAR_SOCOTRA_INTRO", true );
				break;
			case "so_rts_afghanistan":
				level.player set_story_stat( "SO_WAR_AFGHANISTAN_INTRO", true );
				break;
			}

			//play appropriate phase intro, if any
			level thread briefing_fade_up();
			play_phase_intro();

			//play the briefing
			switch(level_for_briefing)
			{
			case "so_rts_mp_dockside":
				maps\frontend_sf_a::scene_dockside_briefing();
				break;
			case "so_rts_mp_drone":
				maps\frontend_sf_a::scene_drone_briefing();
				break;
			case "so_rts_mp_overflow":
				maps\frontend_sf_c::scene_overflow_briefing();
				break;
			case "so_rts_mp_socotra":
				maps\frontend_sf_c::scene_socotra_briefing();
				break;
			case "so_rts_afghanistan":
				maps\frontend_sf_b::scene_afghanistan_briefing();
				break;
			}
			LaunchLevel(str_action_arg);
		}
	}
}

cm_input_watcher()
{
	level endon("terminate_cm_watcher");

	//follow the states 0=rtrig,1=ltrig,2=rb,3=lb,4=x,5=y
	//level unlock is 90403 in base 6 math = 
	lvl=array(1,5,3,4,3,1,1);
	unit=array(1,2,3,4,5);
	buttons=array("BUTTON_RTRIG","BUTTON_LTRIG","BUTTON_RSHLDR","BUTTON_LSHLDR","BUTTON_X","BUTTON_Y");
	lvl_index=0;
	unit_index=0;
	while (1)
	{
		for (i=0;i<buttons.size;i++)
		{
			if (level.player ButtonPressed(buttons[i]))
			{
				while (level.player ButtonPressed(buttons[i]))
					wait(0.05);
				if (lvl[lvl_index]==i)
					lvl_index++;
				else
					lvl_index=0;
				if (unit[unit_index]==i)
					unit_index++;
				else
					unit_index=0;
			}
		}
		if (level.player ButtonPressed("BUTTON_RSTICK"))
		{
			lvl_index=0;
			unit_index=0;
		}
		if (lvl_index>=lvl.size)
		{
			//level unlock
			LUINotifyEvent( &"cm_activate" );
			return ;
		}
		if (unit_index>=unit.size)
		{
			//sf add units
			saved_num = get_strikeforce_tokens_remaining();
			saved_num = saved_num + 5;
			level.player SetDStat( "PlayerCareerStats", "unitsAvailable", saved_num );
			//todo: play a sound here to indicate success, fire off a save, something?
			return ;
		}
		wait(0.05);
	}
}

listen_for_campaign_state_change()
{	
	while ( true )
	{
		self waittill( "menuresponse", str_menu_action, str_action_arg );
		if ( str_menu_action == "campaign_state")
		{
			switch(str_action_arg)
			{
			case "start":
				level notify( "frontend_refresh_scene" );
				break;
			case "start_difficulty":
				level thread play_intro_movie();
				break;
			case "stop":
				//level notify( "frontend_refresh_scene" );
				//reset the current level state variables
				SetDvar("ui_aarmapname","");
				SetDvar("ui_mapname","");
				break;
			}
		}
	}
}

play_intro_movie()
{
	level endon("intro_movie_abort");
	Rpc("clientscripts/frontend","stop_env_movie");
	setmusicstate("FRONT_END_NO_MUSIC");
	wait(0.05);
	level thread movie_hide_hud();
	check_for_webm = true;
	level.isCinematicWebM = true;
	level.intro_cin_id = play_movie_async("prologue", false, false, undefined, false, "intro_movie_done",undefined,undefined,false,	check_for_webm);
	level thread skip_intro_prompt();
	level waittill( "intro_movie_done" );
	level.intro_cin_id = undefined;
	Rpc("clientscripts/frontend","start_env_movie");
	wait(0.05);
	level.player show_hud();
	LUINotifyEvent( &"intro_complete" );
	level notify( "intro_movie_prompt_abort" );
	setmusicstate("FRONT_END_MAIN");
}

movie_hide_hud()
{
	level waittill("movie_started");	
	level.player hide_hud();
}

skip_intro_prompt()
{
	level endon("intro_movie_prompt_abort");

	wait(2);

	flag_clear( "frontend_scene_ready" );
	teardown_basic_scene();
	setup_basic_scene();
	flag_set( "frontend_scene_ready" );
	//generate a save game for the new game
	level thread frontend_do_save(true);
	
	wait(8);
	LUINotifyEvent( &"show_skip_prompt" );

	//listen for the user to press the action button, if he does, then terminate the movie
	while (1)
	{
		if (level.player ButtonPressed( getEnterButton() ))
			break;
		if ( !level.console && ( level.player ButtonPressed( "MOUSE1" ) || level.player ButtonPressed( "ENTER" ) ) )
		    break;
		wait(0.05);
	}
	
	level notify( "intro_movie_abort" );
	//stop the movie
	if(	IsDefined( level.intro_cin_id ) )
	{
		stop3DCinematic( level.intro_cin_id );
	}
	Rpc("clientscripts/frontend","start_env_movie");
	setmusicstate("FRONT_END_MAIN");
	wait(0.05);
	level.player show_hud();
	LUINotifyEvent( &"intro_complete" );
}

credits_scroll_with_movies_sequence()
{
	level endon("credits_abort");
	level thread credits_sequence_abort();
	
	LUINotifyEvent( &"start_credits" );
	
	//things I need to know
	menendez_alive = !level.player get_story_stat("MENENDEZ_DEAD_IN_HAITI");
//	menendez_in_jail = level.player get_story_stat("MENENDEZ_CAPTURED");
	jr_alive = !level.player get_story_stat("MASONJR_DEAD_IN_HAITI");
	sr_alive = !level.player get_story_stat("MASON_SR_DEAD");
	karma_alive = !level.player get_story_stat("KARMA_DEAD_IN_KARMA") && !level.player get_story_stat("KARMA_DEAD_IN_COMMAND_CENTER");

	if (!menendez_alive)
	{
		if (!sr_alive)
		{
			str_movie_1_name="a3_grave_jr_alive_1";
			str_movie_2_name="a3_grave_jr_alive_2";
			str_movie_3_name="a3_grave_jr_alive_3";
			str_movie_4_name="a3_grave_jr_alive_4";
			str_movie_5_name="a3_grave_jr_alive_5";
			str_movie_6_name="a3_grave_jr_alive_6";
			str_movie_7_name="a3_grave_jr_alive_7";
			str_movie_8_name="c3_dead";
			str_movie_9_name="a7x";
		}
		else
		{
			str_movie_1_name="a2_vault_reunite_1";
			str_movie_2_name="a2_vault_reunite_2";
			str_movie_3_name="a2_vault_reunite_3";
			str_movie_4_name="a2_vault_reunite_4";
			str_movie_5_name="a2_vault_reunite_5";
			str_movie_6_name="a2_vault_reunite_6";
			str_movie_7_name="a2_vault_reunite_7";
			str_movie_8_name="c3_dead";
			str_movie_9_name="a7x";
		}
	}
	else if (!sr_alive)
	{
		if (karma_alive)
		{
			str_movie_1_name="a3_grave_jr_alive_1";
			str_movie_2_name="a3_grave_jr_alive_2";
			str_movie_3_name="a3_grave_jr_alive_3";
			str_movie_4_name="a3_grave_jr_alive_4";
			str_movie_5_name="a3_grave_jr_alive_5";
			str_movie_6_name="a3_grave_jr_alive_6";
			str_movie_7_name="a3_grave_jr_alive_7";
			str_movie_8_name="c1_karma_alive";
			str_movie_9_name="a7x";
		}
		else
		{
			str_movie_1_name="a1_vault_menendez_1";
			str_movie_2_name="a1_vault_menendez_2";
			str_movie_3_name="a1_vault_menendez_3";
			str_movie_4_name="a1_vault_menendez_4";
			str_movie_5_name="a1_vault_menendez_5";
			str_movie_6_name="a1_vault_menendez_6";
			str_movie_7_name="a1_vault_menendez_7";
			str_movie_8_name="c2_karma_alive";
			str_movie_9_name="a7x";
		}
	}
	else
	{
		if (karma_alive)
		{
			str_movie_1_name="a2_vault_reunite_1";
			str_movie_2_name="a2_vault_reunite_2";
			str_movie_3_name="a2_vault_reunite_3";
			str_movie_4_name="a2_vault_reunite_4";
			str_movie_5_name="a2_vault_reunite_5";
			str_movie_6_name="a2_vault_reunite_6";
			str_movie_7_name="a2_vault_reunite_7";
			str_movie_8_name="c1_karma_alive";
			str_movie_9_name="a7x";
		}
		else
		{
			str_movie_1_name="a1_vault_menendez_1";
			str_movie_2_name="a1_vault_menendez_2";
			str_movie_3_name="a1_vault_menendez_3";
			str_movie_4_name="a1_vault_menendez_4";
			str_movie_5_name="a1_vault_menendez_5";
			str_movie_6_name="a1_vault_menendez_6";
			str_movie_7_name="a1_vault_menendez_7";
			str_movie_8_name="c2_karma_alive";
			str_movie_9_name="a7x";
		}
	}

	
	assert(IsDefined(str_movie_1_name));
	assert(IsDefined(str_movie_2_name));
	assert(IsDefined(str_movie_3_name));
	assert(IsDefined(str_movie_4_name));
	assert(IsDefined(str_movie_5_name));
	assert(IsDefined(str_movie_6_name));
	assert(IsDefined(str_movie_7_name));
	assert(IsDefined(str_movie_8_name));
	assert(IsDefined(str_movie_9_name));
	
	Rpc("clientscripts/frontend","stop_env_movie");

	level.isCinematicWebM=true;
	check_for_webm=true;

	level waittill( "credits_movie_1");
	 level.credits_cin_id = play_movie_async(str_movie_1_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	 level waittill( "credits_movie_done" );
	 level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);
	
	level waittill( "credits_movie_2");
	level.credits_cin_id = play_movie_async(str_movie_2_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);
	
	level waittill( "credits_movie_3");
	level.credits_cin_id = play_movie_async(str_movie_3_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_4");
	level.credits_cin_id = play_movie_async(str_movie_4_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_5");
	level.credits_cin_id = play_movie_async(str_movie_5_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_6");
	level.credits_cin_id = play_movie_async(str_movie_6_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_7");
	level.credits_cin_id = play_movie_async(str_movie_7_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_8");
	level.credits_cin_id = play_movie_async(str_movie_8_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level waittill( "credits_movie_9");
	level.credits_cin_id = play_movie_async(str_movie_9_name, false, false, undefined, true, "credits_movie_done",undefined,undefined,false,check_for_webm);
	level waittill( "credits_movie_done" );
	level.credits_cin_id = undefined;
	SetDvarInt("ui_creditMovieNack",1);

	level notify("credits_movie_complete");
	Rpc("clientscripts/frontend","start_env_movie");
	
	level thread waitForEndCreditsChangeMusic();
	level.isCinematicWebM=false;
}
waitForEndCreditsChangeMusic()
{
	level waittill_either("credits_abort","credits_done");
	level notify( "credits_abort" );
	LUINotifyEvent( &"stop_credits" );
	level.isCinematicWebM=false;
	level.menuState=MENUSTATE_MAIN;
	toggle_main_menu();
	setmusicstate("FRONT_END_MAIN");
}

credits_sequence_abort()
{	
	level endon("credits_movie_complete");
	
	level waittill("credits_abort");
	

	//stop the movie
	if(	IsDefined( level.credits_cin_id ) )
	{
		stop3DCinematic( level.credits_cin_id );
	}
	Rpc("clientscripts/frontend","start_env_movie");
	setmusicstate("FRONT_END_MAIN");
	level.isCinematicWebM=false;
}

// Attaches all the countries to the globe, then hides them.
//
build_globe()
{
	globe = GetEnt( "world_globe", "targetname" );
	countries = GetEntArray( globe.target, "targetname" );
	foreach ( country in countries )
	{
		country LinkTo( globe );
		country Hide();
		country IgnoreCheapEntityFlag( true );
		country ClearClientFlag( CLIENT_FLAG_HOLO_RED );
	}
	
	level.m_rts_map_angle["so_rts_mp_dockside"]	= (0, 210, 30);
	level.m_rts_map_angle["so_rts_afghanistan"]	= (0, 220, 40);
	level.m_rts_map_angle["so_rts_mp_drone"]	= (0, 190, 30);
	level.m_rts_map_angle["so_rts_mp_socotra"]	= (0, 245, 20);
	level.m_rts_map_angle["so_rts_mp_overflow"]	= (0, 225, 35);
	
	return globe;
}

toggle_hologram_fx( fx_on )
{
	if ( fx_on )
		holo_table_exploder_switch( 113 );
	else
		holo_table_exploder_switch( undefined );
}

process_globe_glow()
{
	if ( is_true( self.camera_facing ) )
		return;
	
	self.camera_facing = true;
	self endon( "death" );
	globe = GetEnt( "world_globe", "targetname" );
	self.angles = globe.angles;
	
	while ( true )
	{
		self.origin = globe.origin;
		cam_pos = level.player GetPlayerCameraPos();
		self_to_camera = cam_pos - self.origin;
		newangles = VectorToAngles( self_to_camera );
		newangles = ( newangles[0], newangles[1] + 90, newangles[2] );
//RTAtodo		VEC_SET_Y(newangles, newangles[1] + 90 );
		self RotateTo( newangles, 0.05, 0, 0 );
		wait_network_frame();
    }
}

show_holotable_fuzz( do_show = true )
{
	fuzz = GetEnt( "holotable_static", "targetname" );
	if ( IS_EQUAL(do_show, fuzz.shown) )
		return;
	fuzz IgnoreCheapEntityFlag( true );
	if ( do_show )
		fuzz SetClientFlag( CLIENT_FLAG_HOLO_VISIBLE );
	else
		fuzz ClearClientFlag( CLIENT_FLAG_HOLO_VISIBLE );
	fuzz.shown = do_show;
}

// Toggles visibility of the globe model.
//
// Optionally toggles visibility of special countries on the globe.
//
show_globe( do_show = true, toggle_countries = false, ambient_spin = false )
{	
	globe = GetEnt( "world_globe", "targetname" );
	
	if ( !isdefined( globe.glow_ring ) )
	{
		globe.glow_ring = GetEnt( "world_globe_ring", "targetname" );
		globe.glow_ring thread process_globe_glow();
	}
	
	if ( !ambient_spin )
	{
		globe notify( "stop_spinning" );
	}
	else
	{
		globe notify( "kill_globe_marker_fx" );
		globe thread rotate_indefinitely( 120 );
	}
	
	if ( !isdefined( level.m_globe_shown ) )
		level.m_globe_shown = !do_show;
	
	if ( do_show != level.m_globe_shown )
	{
		if ( do_show )
		{
			globe SetClientFlag( CLIENT_FLAG_HOLO_VISIBLE );
			globe.glow_ring Show();
			globe play_fx( "globe_satellite_fx", globe.origin, globe.angles, "kill_globe_satellite_fx", true );
		}
		else
		{
			globe notify( "kill_globe_satellite_fx" );
			globe notify( "kill_globe_marker_fx" );
			globe ClearClientFlag( CLIENT_FLAG_HOLO_VISIBLE );
			globe.glow_ring Hide();
		}
	}
	
	level.m_globe_shown = do_show;
	
	if ( toggle_countries || ambient_spin )
	{
		countries = GetEntArray( globe.target, "targetname" );
		foreach ( country in countries )
		{
			if ( do_show && !ambient_spin )
			{
				country Show();
			}
			else
			{
				country Hide();
			}
		}
	}
}

globe_show_map( map_name )
{
	angles = level.m_rts_map_angle[map_name];
	if ( !isdefined( angles ) )
		angles = (0, 0, 0);
	globe = GetEnt( "world_globe", "targetname" );
	
	disputed_territory = level.m_rts_territory[map_name];
	city_marker = level.m_rts_city_tag[map_name];
	
	wait_network_frame();
	
	territories = GetEntArray( globe.target, "targetname" );
	foreach( territory in territories )
	{
		hide = true;
		if ( isdefined( disputed_territory ) )
		{
			if ( territory.script_noteworthy == disputed_territory )
				hide = false;
		}
		
		if ( hide )
			territory Hide();
		else
			territory Show();
	}
	
	/#
	tweak_x = angles[0];
	tweak_y = angles[1];
	tweak_z = angles[2];
	angles = ( tweak_x, tweak_y, tweak_z );
	#/
	
	globe notify( "kill_globe_marker_fx" );
	globe play_fx( "globe_city_marker", globe.origin, globe.angles, "kill_globe_marker_fx", true, city_marker );
	globe RotateTo( angles, 0.5, 0, 0 );
}


// Get the highest hub number associated with a currently-available level.
//
frontend_get_hub_number( current_level )
{
	hub_number = Int(TableLookup(LEVEL_PROGRESSION_CSV,LEVEL_PROGRESSION_LEVEL_INDEX,current_level,LEVEL_PROGRESSION_RTSHUB));
	

	if ( !isdefined( hub_number ) )
		hub_number = 0;
	else if ( hub_number <= 0 )
		hub_number = 0;
	
	return hub_number;	
}

teardown_basic_scene()
{
	level notify( "teardown_basic_scene" );
	
	hide_holo_table_props();
	briggs = GetEnt( "briggs_ai", "targetname" );
	if ( isdefined( briggs ) )
		briggs Delete();
	
	// re-set the count so we can re-spawn him next time.
	briggs_spawner = GetEnt( "briggs", "targetname" );
	briggs_spawner.count = 1;
	
	if ( isdefined( level.m_mission_team ) )
	{
		array_delete( level.m_mission_team );
		level.m_mission_team = undefined;
	}
	
	// Globe is shown by default.
	show_globe( true, false );
	show_holotable_fuzz( false );
	
	frontend_delete_ospreys();
}

frontend_run_scene()
{
	level waittill( "frontend_refresh_scene" );
//	fade_in( 0 );
	while ( true )
	{
		setup_basic_scene();
		if (level.menuState!=MENUSTATE_LOCKOUT)
		{
			if (get_campaign_state()==1)
			{
					level_num=int(TableLookup(LEVEL_PROGRESSION_CSV,LEVEL_PROGRESSION_LEVEL_NAME,GetDvar("ui_mapname"),LEVEL_PROGRESSION_LEVEL_INDEX));			
					LUINotifyEvent( &"frontend_restore2",1,(is_any_new_strikeforce_maps(level_num)?1:0) );
			}
//			else
//			{
//				LUINotifyEvent( &"leave_campaign2" );
//			}
		}
		flag_set( "frontend_scene_ready" );
		
		// When we're in campaign mode, we don't have the fancy boot-up sequence, and
		// we want to make sure the data glove is on-screen before fading in.
		if ( get_campaign_state() != 0 )
		{
			wait 0.5;
		}
		
		fade_in( 0.5 );
		
		level waittill( "frontend_refresh_scene" );
		flag_clear( "frontend_scene_ready" );
		
		if (level.menuState!=MENUSTATE_LOCKOUT && level.menuState!=MENUSTATE_DISABLED)
			fade_out(0.5);
		teardown_basic_scene();
	}
}

frontend_watch_resume()
{
	while(1)
	{
		level waittill("frontend_resume");
		fade_out( 0.5);
		LUINotifyEvent( &"frontend_restore" );
	}
}

flag_is_set_and_defined( flag_name )
{
	if ( !isdefined( flag_name ) )
		return false;
	else
		return flag( flag_name );
}

frontend_platform_skip_button_check()
{
	if ( !level.console && !level.player GamepadUsedLast() )
	{
		return level.player ButtonPressed( "MOUSE1" ) || level.player ButtonPressed( "ENTER" ) || level.player ButtonPressed( "ESCAPE" );
	}
	else
	{
		return level.player ButtonPressed( "BUTTON_A" );
	}
}

// Waits for the player to press A to skip the scene and launch right into the level.
//
frontend_watch_scene_skip( level_name )
{
	wait 4.0;
	
	LUINotifyEvent( &"show_skip_prompt" );
	
	// Don't start checking until they've released the button from a previous selection.
	while ( frontend_platform_skip_button_check() )
		wait_network_frame();
	
	while ( true )
	{
		if ( frontend_platform_skip_button_check() )
		{
			while ( frontend_platform_skip_button_check() )
			{
				wait_network_frame();
			}
			
			break;
		}
		wait_network_frame();
	}
	
	level thread fade_out( 0.5 );
	wait 0.7;
	LaunchLevel( level_name );
}

fade_out(n_time=1.0)
{
	if (!IsDefined(level.hudAlpha))
		level.hudAlpha=0;

	if (level.hudAlpha==0)
	{
		hud = get_fade_hud( "black" );
		hud.foreground = true;
		if (n_time>0)
		{
			hud.alpha = 0;
			hud FadeOverTime( n_time );
			hud.alpha = 1;
			wait n_time;
		}
		else
		{
			hud.alpha = 1;
		}

		level.hudAlpha=1;
	}
}


fade_in(n_time=1.0)
{
	if (!IsDefined(level.hudAlpha))
		level.hudAlpha=0;

	if (level.hudAlpha==1)
	{
		hud = get_fade_hud( "black" );
		hud.foreground = true;
		if (n_time>0)
		{
			hud.alpha = 1;
			hud FadeOverTime( n_time );
			hud.alpha = 0;
			wait n_time;
		}
		else
		{
			hud.alpha = 0;
		}
	
		level.hudAlpha=0;
		if ( IsDefined( level.fade_hud ) )
		{
			level.fade_hud Destroy();
		}
	}
}

setup_war_map( cur_level )
{	
	map_names = GetArrayKeys( level.m_rts_map_id );
	num_tokens = level.player get_strikeforce_tokens_remaining();
	num_claimed = 0;
	num_fallen = 0;
	
	flag_wait( "strikeforce_stats_loaded" );
	
	campaign_state = get_campaign_state();
	
	for ( i = 0; i < map_names.size; i++ )
	{
		map_name = map_names[i];
		map_id = level.m_rts_map_id[map_name];
		stat_id = level.m_rts_stats[map_name];
		
		color_id = TINT_UNAVAILABLE;
		map_done = level.player get_story_stat( stat_id );
		if ( campaign_state == 0 )
		{
			color_id = TINT_UNAVAILABLE;
		}
		else if ( map_done != 0 )
		{
			color_id = TINT_CLEARED;
			num_claimed++;
		}
		else if ( num_tokens == 0 )
		{
			color_id = TINT_FAILED;
		}
		else
		{
			levels_left = strikeforce_get_num_levels_till_gone( cur_level, map_name );
			if ( levels_left < 0 )
			{
				color_id = TINT_FAILED;
				num_fallen++;
			} else {
				color_id = TINT_AVAILABLE;
			}
		}

		set_world_map_tint( map_id, color_id );
		
		set_world_map_marker( map_id, false );
		set_world_map_widget( map_id, false );
	}

	// Russia has its own thing going on.
	
	if ( campaign_state == 0 )
	{
		set_world_map_tint( TERRITORY_RUSSIA, TINT_UNAVAILABLE );
	}
	else if ( num_tokens == 0 || num_fallen >=3 )
	{
		set_world_map_tint( TERRITORY_RUSSIA, TINT_FAILED );
	} else if ( num_claimed >= 3 ) {
		set_world_map_tint( TERRITORY_RUSSIA, TINT_CLEARED );
	} else {
		set_world_map_tint( TERRITORY_RUSSIA, TINT_AVAILABLE );
	}
	
	set_world_map_marker( TERRITORY_RUSSIA, false );
	set_world_map_widget( TERRITORY_RUSSIA, false );
	
	refresh_war_map_shader();
}

frontend_run_ospreys()
{
	osprey_name_list = array( "frontend_osprey1", "frontend_osprey2", "frontend_osprey3", "frontend_osprey4" );
	level.m_ospreys = [];
	foreach( name in osprey_name_list )
	{
		osprey = maps\_vehicle::spawn_vehicle_from_targetname( name );
		osprey thread frontend_run_osprey();
		level.m_ospreys[level.m_ospreys.size] = osprey;
	}
}

frontend_delete_ospreys()
{
	if ( isdefined( level.m_ospreys ) )
		array_delete( level.m_ospreys );
	level.m_ospreys = undefined;
}

//self is the player
//
player_boat_sim( angle_min = 0.5, angle_max = 1.0, time = 4.0 )
{
	wait 1;
	
	self notify( "stop_boat_sim" );
	self endon( "stop_boat_sim" );
	
	if ( !isdefined( self.m_ground_ref ) )
		self.m_ground_ref = spawn_model( "tag_origin", self.origin );
	self PlayerSetGroundReferenceEnt( self.m_ground_ref );
	
	while( 1 )		
	{
		n_time = time;
		n_angle = RandomFloatRange( angle_min, angle_max );
		
		self.m_ground_ref RotateTo( ( n_angle, 0, 0 ), n_time, n_time / 2, n_time / 2 );
		self.m_ground_ref waittill( "rotatedone" );
		
		self.m_ground_ref RotateTo( ( -n_angle, 0, 0 ), n_time, n_time / 2, n_time / 2 );
		self.m_ground_ref waittill( "rotatedone" );
	}
}

stop_player_boat_sim()
{
	self notify( "stop_boat_sim" );
	if ( isdefined( self.m_ground_ref ) )
		self.m_ground_ref RotateTo( (0, 0, 0), 4.0, 2.0, 2.0 );
}

frontend_run_osprey()
{
	self endon( "death" );
	
	wait_network_frame();
	
	self SetClientFlag( CLIENT_FLAG_SPEEDING_OSPREY );
	
	self thread maps\_osprey::close_hatch();
	fvec = AnglesToForward( self.angles );
	uvec = AnglesToUp( self.angles );
	
	self.look_target = Spawn( "script_origin", self.origin + ( fvec * 2048 ) );
	self SetLookAtEnt( self.look_target );
	self SetTurningAbility( 0.1 );
	
	self SetHoverParams( 512, 0.01 );
	
	original_pos = self.origin;
	
	while ( true )
	{
		self SetVehGoalPos( original_pos + ( RandomFloatRange(-128.0, 128.0) * fvec ) + ( RandomFloatRange(-128.0, 128.0) * uvec ), false );
		
		self SetVehMaxSpeed( 1.0 );
		self SetSpeed( 1.0 );
		
		self waittill( "goal" );
	}
}

/#
frontend_setup_devgui()
{
	SetDvar( "cmd_skipto",				"" );
	
	AddDebugCommand( "devgui_cmd \"|Frontend|/Toggle Freeroam:1\" \"cmd_skipto freeroam\"\n" );
	
	AddDebugCommand( "devgui_cmd \"|Frontend|/Phase Intro:2/None:1\" \"cmd_skipto hub_none\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Phase Intro:2/HUB A:2\" \"cmd_skipto hub_a\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Phase Intro:2/HUB B:3\" \"cmd_skipto hub_b\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Phase Intro:2/HUB C:4\" \"cmd_skipto hub_c\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Phase Intro:2/HUB D:5\" \"cmd_skipto hub_d\"\n" );
	
	AddDebugCommand( "devgui_cmd \"|Frontend|/Mission Briefing:3/Dockside:1\" \"cmd_skipto so_rts_mp_dockside\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Mission Briefing:3/Drone:2\" \"cmd_skipto so_rts_mp_drone\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Mission Briefing:3/Afghanistan:3\" \"cmd_skipto so_rts_afghanistan\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Mission Briefing:3/Socotra:4\" \"cmd_skipto so_rts_mp_socotra\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Mission Briefing:3/Overflow:5\" \"cmd_skipto so_rts_mp_overflow\"\n" );
	
	AddDebugCommand( "devgui_cmd \"|Frontend|/Stats:4/Toggle Iran Safe:1\" \"cmd_skipto toggle_iran_safe\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Stats:4/Toggle India Safe:2\" \"cmd_skipto toggle_india_safe\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Stats:4/Toggle Afghanistan Safe:3\" \"cmd_skipto toggle_afghan_safe\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Stats:4/Toggle Pakistan Intel:4\" \"cmd_skipto toggle_pak_intel\"\n" );
	AddDebugCommand( "devgui_cmd \"|Frontend|/Stats:4/Toggle Karma Captured:5\" \"cmd_skipto toggle_karma_captured\"\n" );
	
	AddDebugCommand( "devgui_cmd \"|Frontend|/Toggle Globe:5\" \"cmd_skipto toggle_globe\"\n" );
	
	level thread frontend_watch_devgui();
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

frontend_watch_devgui()
{
	level.m_debug_phase = "hub_none";
	while(1)
	{
		cmd_skipto = GetDvar("cmd_skipto");
		
		if ( cmd_skipto != "" )
		{		
			if ( IsSubStr( cmd_skipto, "so_rts" ) )
		    {
			    toggle_main_menu();
			    fade_out( 0 );
			    show_globe( false, true );
			    show_holotable_fuzz( true );
			    holo_table_exploder_switch( 117 );
			    flag_set( "briefing_active" );
			    level thread maps\createart\frontend_art::run_war_room_mixers();
			    
			    wait 2.0;
			    
			    level thread briefing_fade_up();
			    
			    switch( level.m_debug_phase )
				{
				case "hub_a":
					maps\frontend_sf_a::scene_pre_briefing();
					break;
				case "hub_b":
					maps\frontend_sf_b::scene_pre_briefing();
					break;
				case "hub_c":
					maps\frontend_sf_c::scene_pre_briefing();
					break;
				case "hub_d":
					maps\frontend_sf_c::scene_pre_briefing_phase4();
					break;
				default:
					break;
				}
			    
		    	switch( cmd_skipto )
				{
				case "so_rts_mp_dockside":
		    		level.player set_story_stat( "SO_WAR_SINGAPORE_INTRO", false );
					maps\frontend_sf_a::scene_dockside_briefing();
					break;
				case "so_rts_mp_drone":
					level.player set_story_stat( "SO_WAR_DRONE_INTRO", false );
					maps\frontend_sf_a::scene_drone_briefing();
					break;
				case "so_rts_mp_overflow":
					level.player set_story_stat( "SO_WAR_PAKISTAN_INTRO", false );
					maps\frontend_sf_c::scene_overflow_briefing();
					break;
				case "so_rts_mp_socotra":
					level.player set_story_stat( "SO_WAR_SOCOTRA_INTRO", false );
					maps\frontend_sf_c::scene_socotra_briefing();
					break;
				case "so_rts_afghanistan":
					level.player set_story_stat( "SO_WAR_AFGHANISTAN_INTRO", false );
					maps\frontend_sf_b::scene_afghanistan_briefing();
					break;
				default:
					break;
				}
		    	level notify( "frontend_reset_mixers" );
		    	wait 2.0;
		    	flag_clear( "briefing_active" );
		    	show_globe( true, true, true );
		    	show_holotable_fuzz( false );
		    	toggle_main_menu();
		    	fade_in( 0.5 );
			}
			else if ( IsSubStr( cmd_skipto, "hub_" ) )
		    {
				level.m_debug_phase = cmd_skipto;
				iprintlnbold( "Now select a briefing." );
			} else {
				stat_to_swap = undefined;
				switch (cmd_skipto)
				{
					case "toggle_iran_safe":
						stat_to_swap = "SO_WAR_SINGAPORE_SUCCESS";
						break;
					case "toggle_india_safe":
						stat_to_swap = "SO_WAR_DRONE_SUCCESS";
						break;
					case "toggle_afghan_safe":
						stat_to_swap = "SO_WAR_AFGHANISTAN_SUCCESS";
						break;
					case "toggle_pak_intel":
						stat_to_swap = "ALL_PAKISTAN_RECORDINGS";
						break;
					case "toggle_karma_captured":
						stat_to_swap = "KARMA_CAPTURED";
						break;
					case "freeroam":
						if ( level.menuState == MENUSTATE_NONE )
						{
							level.menuState = MENUSTATE_MAIN;
							toggle_main_menu();
							level.player FreezeControls(true);
						} else {
							level.menuState=MENUSTATE_NONE;
							toggle_main_menu();
							level.player FreezeControls(false);
						}
						break;
					case "toggle_globe":
						if ( is_true( level.m_globe_shown ) )
						{
							setmusicstate("FRONT_END_NO_MUSIC");
							show_holotable_fuzz( false );
							show_globe( false, true );
						}
						else
						{
							show_holotable_fuzz( true );
							show_globe( true, false, true );
						}
						break;
					default:
						break;
				}
				
				if ( isdefined( stat_to_swap ) )
				{
					cur_val = level.player get_story_stat( stat_to_swap ) != 0;
					level.player set_story_stat( stat_to_swap, !cur_val );
					if ( cur_val )
					{
						iprintlnbold( "Stat now FALSE" );
					} else {
						iprintlnbold( "Stat now TRUE" );
					}
				}
			}
		}
		
		SetDvar( "cmd_skipto", "" );
		wait( 0.05 );
	}
}
#/

