return {
    toggle_key='F8', reset_key='F9',
    fov=110, camera_tilt=25, radius=0.12, speed_preset=2,
    max_distance=0, -- metres; 0 disables the optional distance limit
    collision=true,
    gravity=9.81, thrust_to_weight=5.0, throttle_curve=0.25,
    roll_rate=650, pitch_rate=650, yaw_rate=500,
    expo=0.35, deadband=0.025,
    rate_response=0.035, motor_response=0.045,
    linear_drag=0.12, quadratic_drag=0.018,
    restitution=0.10, surface_friction=0.8, step=1/240,
    -- Defaults assume EdgeTX AETR. Calibrate using ZoneFPVInput.exe --calibrate.
    roll_axis=1,pitch_axis=2,throttle_axis=3,yaw_axis=4,
    roll_invert=false,pitch_invert=false,throttle_invert=false,yaw_invert=false,
    toggle_button=0, -- 0=disabled; 1..32=USB joystick button
}
