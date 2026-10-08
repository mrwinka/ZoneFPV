-- Installed-game assets inspected with retoc; no generated material/shader.
-- Reproducible binary evidence: build/v9-vision-asset-proof.py.
local M={}

-- The InterchangeAssets plugin package is cooked in pakchunk0-Windows.
-- UMaterial serialized schema proves Opaque + Unlit + SkeletalMesh usage.
-- White default texture allows the RGBA factor to color the entire mesh;
-- the normal mesh depth test keeps solid walls in front of the silhouette.
M.silhouette={
    path='/InterchangeAssets/gltf/M_Unlit.M_Unlit',
    color_parameter='BaseColorFactor',
    texture_parameter='BaseColorTexture',
    white_texture='/InterchangeAssets/gltf/Textures/T_White_srgb.T_White_srgb',
    alpha_parameter='AlphaCutoff',
    skeletal_usage=true,unlit=true,opaque=true,
}

-- This game-owned emitter is a secondary option if a plugin mount is absent.
-- Its cooked SkeletalMesh usage and opaque blend are also explicitly proven.
-- Hue is controlled by a scalar, so it is not an arbitrary RGB material.
-- Uniform emissive surface with cooked SkeletalMesh usage. Its filter map is
-- replaced with verified opaque white, making UVs independent of the outfit.
-- Unlike the coils emitter it has explicit RGB and luminance controls.
M.uniform_emissive={
    path='/DatasmithContent/Materials/StdEmissive/M_StdEmissive.M_StdEmissive',
    color_parameter='LuminanceFilter',
    intensity_parameter='LuminanceAmount',
    texture_parameter='LuminanceFilterMap',
    white_texture='/InterchangeAssets/gltf/Textures/T_White_srgb.T_White_srgb',
    unit_color=true,skeletal_usage=true,masked=true,
}

M.emissive_fallback={
    path='/Game/_Stalker_2/Materials/M_korshunov_coils_emissive.M_korshunov_coils_emissive',
    heat_parameter='CoilsHeatValue',
    intensity_parameter='Korshunov_EmissiveMult',
    skeletal_usage=true,opaque=true,
}

M.nightvision={
    path='/Game/_Stalker_2/Materials/PostProcess/NVG/PPI_NVG_03.PPI_NVG_03',
    white_phosphor_path='/Game/_Stalker_2/Materials/PostProcess/NVG/PPI_NVG_03_WP.PPI_NVG_03_WP',
    intensity_parameter='NVG Intensity',
    color_parameter='NVG Color',
    brightness_parameter='Final Brightness',
    gamma_parameter='Color Gamma',
    noise_parameter='Noise Intensity',
    -- Native NVG additionally reads MPC_PostProcess activation/feedback.
    -- Camera-local exposure and grading must provide a usable image even
    -- when the player-owned MPC activation marker keeps this effect idle.
    activation_collection='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess',
    activation_parameter='NVGActivationMarker',
}

return M
