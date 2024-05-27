#include common_scripts\utility;
#include maps\_utility;
#include maps\_dialog;
#include maps\_scene;
#include maps\panama_utility;
#include maps\_vehicle;
#include maps\_objectives;
#include maps\_music;

skipto_house()
{
	skipto_setup();
	skipto_teleport_players("player_skipto_house");
}

panama_wind_settings()
{
	SetSavedDvar( "wind_global_vector", "246.366 0 0" );						// change "1 0 0" to your wind vector
	SetSavedDvar( "wind_global_low_altitude", 0 );						// change 0 to your wind's lower bound
	SetSavedDvar( "wind_global_hi_altitude", 5000 );					// change 10000 to your wind's upper bound
	SetSavedDvar( "wind_global_low_strength_percent", 0.5 );	// change 0.5 to your desired wind strength percentage	
}

main()
{
	level thread house_ik_headtracking_limits();
	level thread blackscreen( 0, 2, 0 );
	level thread maps\createart\panama_art::house();

	level.player_interactive_model = "c_usa_woods_panama_casual_viewbody";

	house_intro_setup();

	level thread screen_fade_in( 0.15 );

	level.hummerSoundEnt = Spawn( "script_origin", ( 24315, -20231, 111 ) );
	level.hummerSoundEnt PlayLoopSound( "evt_mason_vehicle_idle_loop", 3 );

	level.player AllowCrouch( false );
	level.player AllowProne( false );

	player_exits_hummer();

	// fail if player is dumb and wanders off in the streets
	level.player thread street_fail_condition();

	house_events();

	level.player_interactive_model = "c_usa_woods_panama_viewbody";

	level thread old_man_woods( "panama_int_1" );
	level thread house_clean_up_and_reset();
	level thread restore_ik_headtracking_limits();

	level.player AllowCrouch( true );
	level.player AllowProne( true );

	level waittill( "movie_done" );

	screen_fade_out( 0.5 );

	flag_set( "house_event_end" );
}

house_ik_headtracking_limits()
{
	SetSavedDvar( "ik_pitch_limit_thresh", 20 );
	SetSavedDvar( "ik_pitch_limit_max", 70 );
	SetSavedDvar( "ik_roll_limit_thresh", 40 );
	SetSavedDvar( "ik_roll_limit_max", 100 );
	SetSavedDvar( "ik_yaw_limit_thresh", 20 );
	SetSavedDvar( "ik_yaw_limit_max", 90 );
}

house_intro_setup()
{
	level.ai_mason_casual = simple_spawn_single( "ai_mason_casual", ::init_casual_hero );
	level.ai_mason_casual.animname = "mason";
	level ClientNotify( "sscig" );

	run_scene_first_frame( "house_front_door" );
	run_scene_first_frame( "front_gate" );
	run_scene_first_frame( "get_bag_door" );
	run_scene_first_frame( "outro_back_gate" );

	level thread run_scene( "civ_idle_1" );
	level thread run_scene( "civ_idle_2" );
	level thread run_scene( "civ_idle_3" );
	level thread run_scene( "civ_idle_4" );
	level thread run_scene( "civ_idle_5" );

	level thread run_scene( "skinner_jane_argue_loop" );

	//hide graffiti
	m_gringo_graffiti = GetEnt( "m_gringo_graffiti", "targetname" );
	m_gringo_graffiti Hide();

	level.player init_player();

	exploder( 1001 );

	flag_wait( "skinner_jane_argue_loop_started" );

	level thread get_skinner_ai();
}

get_skinner_ai()
{
	flag_wait( "mason_greets_mcknight_started" );

	level.ai_skinner_casual = GetEnt( "skinner_ai", "targetname" );
}

// self == player
init_player()
{
	self AllowJump( false );
	self AllowSprint( false );
	self hide_hud();

	SetSavedDvar( "vehicle_riding", "0" );

	self thread take_and_giveback_weapons( "house_event_end" );
	self thread walk_speed_adjustment();
}

// self == mason
init_casual_hero()
{
	self endon( "death" );

	self make_hero();
	self gun_remove();
	self.ignoreme = true;
	self.ignoreall = true;
}

// self == player
walk_speed_adjustment()
{
	level endon( "player_outro_started" );

	const n_dist_min = 128;
	const n_dist_max = 256;

	self.n_speed_scale_min = 0.35;
	self.n_speed_scale_max = 0.65;

	while ( true )
	{
		n_dist = Distance2D( level.player.origin, level.ai_mason_casual.origin );

		if ( n_dist < n_dist_min )
			self SetMoveSpeedScale( self.n_speed_scale_min );
		else if ( n_dist > n_dist_max )
			self SetMoveSpeedScale( self.n_speed_scale_max );
		else
		{
			n_speed_scale = linear_map( n_dist, n_dist_min, n_dist_max, self.n_speed_scale_min, self.n_speed_scale_max );

			self SetMoveSpeedScale( n_speed_scale );
		}

		wait 0.05;
	}
}

// self == player
street_fail_condition()
{
	level endon( "player_opened_shed" );

	t_warn_player = GetEnt( "warn_player", "targetname" );
	t_warn_player thread house_warn_player_logic();
	t_fail_player = GetEnt( "fail_player", "targetname" );

	while ( true )
	{
		if ( !( self IsTouching( t_fail_player ) ) )
			missionfailedwrapper( &"PANAMA_STREET_FAIL" );

		wait 0.05;
	}
}

// self == warning trigger
house_warn_player_logic()
{
	level endon( "player_opened_shed" );

	while ( true )
	{
		if ( !( level.player IsTouching( self ) ) )
		{
			screen_message_create( &"PANAMA_STREET_WARNING" );

			wait 3;

			screen_message_delete();
		}

		wait 0.05;
	}
}

house_clean_up_and_reset()
{
	//destroy hat hud
	level notify( "hat_off" );

	a_house_vehicles = GetEntArray( "house_vehicles", "script_noteworthy" );

	foreach ( vehicle in a_house_vehicles )
	{
		if ( IsDefined( vehicle ) )
		{
            vehicle.delete_on_death = 1;
            vehicle notify( "death" );

            if ( !isalive( vehicle ) )
                vehicle delete();
        }
    }

	//just in case
	a_ai = GetAIArray();

	foreach ( ai in a_ai )
		ai Delete();

	a_house_triggers = GetEntArray( "house_trigger", "script_noteworthy" );

	foreach ( t_house in a_house_triggers )
		t_house Delete();

	flag_wait( "house_event_end" );

	level.player SetMoveSpeedScale( 1 );
	level.player AllowSprint( true );
	level.player AllowJump( true );
	level.player show_hud();
	level.player notify( "house_event_end" );
}

player_exits_hummer()
{
	vh_player_hummer = GetEnt( "vh_player_humvee", "targetname" );
	vh_player_hummer veh_toggle_tread_fx( false );
	vh_player_hummer veh_toggle_exhaust_fx( false );
	vh_player_hummer Attach( "veh_iw_hummer_win_xcam", "front_door_left_jnt" );

//	run_scene_first_frame( "player_exits_hummer_xcam" );
//	m_humvee = get_model_or_models_from_scene( "player_exits_hummer_xcam", "player_hummer_xcam" );
//	e_humvee_extra_cam = GetEnt( "extra_cam_humvee", "targetname" );
//	e_humvee_extra_cam LinkTo( m_humvee, "front_door_left_jnt" );

	wait 0.3;

	turn_on_reflection_cam( "extra_cam_humvee" );

	level thread house_drive_by();
	level thread run_scene( "player_exits_hummer_xcam" );
	level thread run_scene( "mason_sits_hummer" );

	m_nocap_hair = get_model_or_models_from_scene( "player_exits_hummer_xcam", "reflection_woods" );
	m_nocap_hair Attach( "c_usa_milcas_woods_hair", "J_HEAD" );

	level thread run_scene( "player_exits_hummer" );

	wait 6;

	m_nocap_hair Detach( "c_usa_milcas_woods_hair", "J_HEAD" );
	m_nocap_hair Attach( "c_usa_milcas_woods_hair_cap", "J_HEAD" );

	scene_wait( "player_exits_hummer" );

	level thread toggle_hat_overlay();

	vh_player_hummer Detach( "veh_iw_hummer_win_xcam", "front_door_left_jnt" );
	turn_off_reflection_cam( "extra_cam_humvee" );
}

house_drive_by()
{
	wait 5.5;

	vh_hatch = spawn_vehicle_from_targetname( "pan_truck" );
	vh_hatch setmovingplatformenabled( 1 );
	vh_hatch hidepart( "tag_glass_left_front" );
	vh_hatch thread go_path( GetVehicleNode( "drive_by_path", "targetname" ) );
	vh_hatch thread truck_play_music();

	level thread run_scene( "gringo_driveby" );

	wait 3;

	vh_truck_driveway = GetEnt( "truck_driveway", "targetname" );
	vh_truck_driveway thread go_path( GetVehicleNode( "start_driveway", "targetname" ) );

	wait 4;

	level thread ambient_neighborhood_vehicles();
}

truck_play_music()
{
	music_ent = Spawn( "script_origin", self.origin );
	music_ent PlayLoopSound( "mus_intro_truck" );
	music_ent LinkTo( self );
}

ambient_neighborhood_vehicles()
{
	level endon( "player_at_front_gate" );

	while ( true )
	{
		if ( RandomInt(3) == 0 )
			vh_ambient = "pan_hatchback";
		else if ( RandomInt(3) == 1 )
			vh_ambient = "pan_van";	
		else
			vh_ambient = "pan_truck";

		if ( RandomInt(4) == 0 )
			nd_start = GetVehicleNode( "start_sideroad_1", "targetname" );
		else if ( RandomInt(4) == 1 )
			nd_start = GetVehicleNode( "start_sideroad_2", "targetname" );
		else if ( RandomInt(4) == 2 )
			nd_start = GetVehicleNode( "start_sideroad_3", "targetname" );
		else
			nd_start = GetVehicleNode( "start_sideroad_4", "targetname" );

		vh_car = spawn_vehicle_from_targetname( vh_ambient );
		vh_car thread go_path( nd_start );

		wait RandomFloatRange( 2.5, 4.5 );
	}
}

house_events()
{
	flag_set( "house_meet_mason" );
	autosave_by_name( "house_start" );

	house_event_front();
	house_event_walk_to_shed();
	house_event_backyard();
	house_event_exit();
}

house_event_front()
{
	vh_mason_hummer = GetEnt( "mason_hummer", "targetname" );
	vh_mason_hummer thread turn_off_mason_hummer();

    level thread start_mcknight_arguing_vo();
	
	trigger_wait( "trig_mason_greet" );
	
	flag_set( "house_follow_mason" );

    level thread after_meeting_mason_driveby();
	level thread house_frontyard_obj();

	stop_exploder( 1001 );

	wait 0.05;

	exploder( 1002 );

	level thread run_scene( "mason_greets_mcknight" );
	level.player say_dialog( "mason_002", 2 );
	level.player say_dialog( "you_too_alex_004", 4.5 );

	scene_wait( "mason_greets_mcknight" );

	level thread mason_front_gate_nag();
	level thread run_scene( "mason_wait_gate" );
}

after_meeting_mason_driveby()
{
    wait 8;
    pickup = spawn_vehicle_from_targetname( "pickup_drive_by_after_mason" );
    pickup setmovingplatformenabled( 1 );
    pickup thread go_path( getvehiclenode( "start_drive_by_after_mason", "targetname" ) );
}

house_event_walk_to_shed()
{
	trigger_wait( "trig_front_gate" );
	flag_set( "player_at_front_gate" );

	m_front_gate_clip = GetEnt( "m_front_gate_clip", "targetname" );
	m_front_gate_clip MoveTo( m_front_gate_clip.origin - ( 0, 0, 128 ), 0.05 );

	level thread run_scene( "squad_to_backyard" );
	level thread run_scene( "front_gate" );
	level thread open_front_gate_clip();

	level.mason = get_ais_from_scene( "squad_to_backyard", "mason" );
	level.mason attach( "p6_anim_beer_can", "tag_weapon_left" );
	level.mcknight attach( "p6_anim_beer_can", "tag_weapon_left" );

	m_front_gate_clip thread front_gate_close_wait();

	level thread shed_door_wait();

	level.player thread say_dialog( "maso_hey_mcknight_you_g_0", 8 ); // Hey McKnight - You got the stuff?
	
	level.player.n_speed_scale_min = 0.2;
	level.player.n_speed_scale_max = 0.2;
	level.player thread increase_player_speed_after_dog_leaves();

	stop_exploder( 1002 );

	wait 0.05;

	exploder( 1003 );
}

open_front_gate_clip()
{
    wait 1.5;
    front_gate_clip = getent( "backyard_gate_clip", "targetname" );
    front_gate_clip rotateyaw( 110, 1.2 );
    level waittill( "player_opened_shed" );
    front_gate_clip delete();
}

increase_player_speed_after_dog_leaves()
{
	wait 16;

	IPrintLnBold( "done" );

	level.player.n_speed_scale_min = 0.35;
	level.player.n_speed_scale_max = 0.65;
}

house_event_backyard()
{
	trigger_wait( "trig_use_shed_door" );

	stop_exploder( 1002 );

	level thread maps\_audio::switch_music_wait( "PANAMA_INTRO", 17 );

	flag_set( "player_opened_shed" );
	turn_on_reflection_cam( "reflection_cam" );

	m_shed_door_extra = GetEnt( "m_mirrored_shed_door", "targetname" );
	m_shed_door_extra Delete();

	level thread run_scene( "reflection_woods_grabs_bag" );
	level thread run_scene( "reflection_woods_grabs_bag_door" );
	level thread run_scene( "get_bag_door" );
	level thread run_scene( "get_bag" );

	wait 5;

	turn_off_reflection_cam( "reflection_cam" );
	scene_wait( "get_bag" );

	flag_set( "player_frontyard_obj" );

	run_scene_first_frame( "get_bag_door" );

	level thread paint_spray();
	level thread run_scene( "leave_table" );

	level.mason Detach( "p6_anim_beer_can", "tag_weapon_left" );

	level thread run_scene( "masons_beer_loop" );
	level thread mason_mcknight_wait_at_gate();
	level thread gringo_spraypaint_vo();
}

mason_mcknight_wait_at_gate()
{
	level endon( "house_player_at_exit" );

	scene_wait( "leave_table" );
	run_scene( "leave_table_wait_VO" );

	level thread run_scene( "leave_table_wait" );

	level thread exit_gate_nag();
}

house_event_exit()
{
	trigger_wait( "trig_exit_gate" );

	flag_set( "house_player_at_exit" );

	SetMusicState(" PANAMA_GATE_OPENED" );

	m_gringo_graffiti = GetEnt( "m_gringo_graffiti", "targetname" );
	m_gringo_graffiti Show();

	delay_thread( 6, ::flag_set, "show_introscreen_title" );

	level thread house_end_flag();
	level thread run_scene_and_delete( "outro_back_gate", 1 );

	level notify( "stop_painting" ); // for sound

	level.player startcameratween( 1 );

	level thread run_scene_and_delete( "player_outro", 1 );
	level thread hide_beer_can();

	flag_wait( "player_outro_started" );

	ai_tagger = GetEnt( "gringo_tagger_ai", "targetname" );
	ai_tagger Attach( "p_glo_spray_can", "tag_weapon_left" );

	level thread fade_out_house_end();

	scene_wait( "player_outro" );

	run_scene_first_frame( "zodiac_approach_player" );
	run_scene_first_frame( "zodiac_approach_mason" );
	run_scene_first_frame( "zodiac_approach_seals" );
	run_scene_first_frame( "zodiac_approach_seals2" );
	run_scene_first_frame( "zodiac_approach_boat" );
}

hide_beer_can()
{
	level waittill( "player_outro_started" );

	beer_can = get_model_or_models_from_scene( "player_outro", "beer" );
	beer_can hide();
}

#using_animtree( "player" );

fade_out_house_end()
{
	anim_length = GetAnimLength( %ch_pan_01_07_gringos_player );

	wait( anim_length - 2.1 );

	level notify( "hat_off" );

	level thread screen_fade_out( 2 );

	flag_wait( "movie_started" );

	wait 0.5;

	screen_fade_in( 1 );
}

// self == mason's hummer
turn_off_mason_hummer()
{
	trigger_wait( "trig_turn_off_mason_car" );

	level.hummerSoundEnt StopLoopSound( 0.25 );
	level.hummerSoundEnt PlaySound( "evt_mason_vehicle_idle_stop" );

	self veh_toggle_tread_fx( false );
	self veh_toggle_exhaust_fx( false );

	wait 4;

	level.hummerSoundEnt Delete();
}

// self == front gate clip
front_gate_close_wait()
{
	trigger_wait( "trig_use_shed_door" );

	run_scene_first_frame( "front_gate" );

	m_front_door_open_clip = GetEnt( "front_gate_open", "targetname" );
	m_front_door_open_clip Delete();

	self MoveTo( self.origin + ( 0, 0, 128 ), 0.05 );
}

shed_door_wait()
{
	level endon( "player_opened_shed" );

	scene_wait( "squad_to_backyard" );

	level thread run_scene( "beer_loop" );

	level thread shed_door_nag();
	level thread run_scene( "wait_table" );
}

house_end_flag()
{
	flag_wait( "player_outro_started" );
	run_scene_first_frame( "house_end_flag" );

	level waittill( "start_flag" );

	run_scene( "house_end_flag" );
}

turn_on_reflection_cam( str_extra_cam )
{
	SetSavedDvar( "r_extracam_custom_aspectratio", 1.38636 );
	sm_cam_ent = GetEnt( str_extra_cam, "targetname" );

	level.e_tag_origin = Spawn( "script_model", sm_cam_ent.origin );
	level.e_tag_origin SetModel( "tag_origin" );
	level.e_tag_origin.angles = sm_cam_ent.angles;

	level.e_tag_origin SetClientFlag( 1 );
}

turn_off_reflection_cam( str_extra_cam )
{
	sm_cam_ent = GetEnt( str_extra_cam, "targetname" );

	level.e_tag_origin ClearClientFlag( 1 );
	level.e_tag_origin delay_thread( 2, ::self_delete );

	sm_cam_ent delay_thread( 2, ::self_delete );
}

skinner_wave_us_back( ai_mason )
{
	autosave_by_name( "house_front" );
	end_scene( "skinner_jane_argue_loop" );

	level thread house_frontyard_obj();
	level thread run_scene( "house_front_door" );

	run_scene( "skinner_waves_us_back" );
}

house_frontyard_obj()
{
	wait 10;
	
	flag_set( "house_front_door_obj_done" );
	
	wait 6;
	
	flag_set( "house_front_gate_obj" );
}

mason_front_gate_nag()
{
	level endon( "player_at_front_gate" );

	add_vo_to_nag_group( "front_gate_nag", level.ai_mason_casual, "we_should_make_thi_007" ); // We should make this quick, Woods.
	add_vo_to_nag_group( "front_gate_nag", level.ai_mason_casual, "for_the_sake_of_sk_008" ); // For the sake of McKnight's marriage if nothing else.
	add_vo_to_nag_group( "front_gate_nag", level.ai_mason_casual, "maso_come_on_frank_0" ); // Come on, Frank.

	wait 5;

	level thread start_vo_nag_group_flag( "front_gate_nag", "player_at_front_gate", 8 );
}

shed_door_nag()
{
	level endon( "player_opened_shed" );

	add_vo_to_nag_group( "shed_door_nag", level.ai_skinner_casual, "come_on_woods__w_017" ); // What are you waiting for, Frank?

	level thread start_vo_nag_group_flag( "shed_door_nag", "player_opened_shed", 16, 3, false, 3 );
}

exit_gate_nag()
{
	level endon( "house_player_at_exit" );

	add_vo_to_nag_group( "exit_gate_nag", level.ai_skinner_casual , "hey_woods__what_a_029" ); // Hey Woods, what are you waiting for?
	add_vo_to_nag_group( "exit_gate_nag", level.ai_skinner_casual, "come_on_030" ); // Come on!

	level thread start_vo_nag_group_flag( "exit_gate_nag", "house_player_at_exit", 16, 3, false, 3 );
}

toggle_hat_overlay()
{
	overlay = NewClientHudElem( level.player );
	overlay.x = 0;
	overlay.y = 0;
	overlay SetShader( "ballcap_panama_overlay", 640, 480 );
	overlay.splatter = true;
	overlay.alignX = "left";
	overlay.alignY = "top";
	overlay.sort = 1;
	overlay.foreground = 0;
	overlay.horzAlign = "fullscreen";
	overlay.vertAlign = "fullscreen";
	overlay.alpha = 1;
	//overlay FadeOverTime( 10 ); 
	//overlay.alpha = 0;

	level waittill( "hat_off" );

	overlay Destroy();
}

player_woods_dialog()
{
	level.player thread say_dialog( "mason_002" ); // Mason.
}

paint_spray()
{
	// Start the looping sound of spray paint
	paintent = Spawn( "script_origin" , ( 24362, -20164, 56 ) );
	paintent PlayLoopSound( "evt_spray_paint_loop" );

	level waittill( "stop_painting" ); 

	paintent StopLoopSound( 0. );
	paintent Delete();
}

start_mcknight_arguing_vo()
{
	level endon( "kill_argue_vo" );

	spawner = GetEnt( "skinner", "targetname" );

	level.mcknight = simple_spawn_single( "skinner" );
	level.mcknight.animname = "skinner";
	level.mcknight forceteleport( spawner.origin, spawner.angles );

	skinner_vo = getent( "skinner_vo", "targetname" );
	skinner_vo say_dialog( "mckn_honey_you_need_to_0", 0, 1 );
	skinner_vo say_dialog( "jane_i_am_calm_0", 0, 1 );

	flag_wait( "house_follow_mason" );

	wait 5;

	skinner_vo playsound( "fly_pan_house_start" );
	skinner_vo say_dialog( "jane_five_years_mark_w_0", 0, 1 );
}

mcknight_close_the_door_argument_vo( guy )
{
	skinner_vo = GetEnt( "skinner_vo", "targetname" );
	skinner_vo say_dialog( "mckn_family_i_thought_th_0", 0, 1 );
	skinner_vo say_dialog( "jane_it_s_about_everythin_0", 0, 1 );
	skinner_vo PlaySound( "fly_pan_house_end" );
	skinner_vo say_dialog( "jane_i_need_something_mor_0", 0, 1 );
	skinner_vo say_dialog( "jane_it_s_not_enough_mar_0", 0, 1 );
}

#using_animtree( "generic_human" );

gringo_spraypaint_vo()
{
	level endon( "player_outro_started" );

	time = GetAnimLength( %ch_pan_01_06_intro_backyard_leave_mason );

	wait ( time - 10 );

	m_gringo_graffiti = GetEnt( "m_gringo_graffiti", "targetname" );
	m_gringo_graffiti say_dialog( "tee1_hurry_it_up_0", 3, 1 );
	m_gringo_graffiti say_dialog( "tee2_okay_okay_0", 2, 1 );
	m_gringo_graffiti say_dialog( "tee1_that_s_good_come_0", 2, 1 );
	m_gringo_graffiti say_dialog( "tee2_go_go_go_0", 1, 1 );
}