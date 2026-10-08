-- Stable saved IDs: v9/v10 modes 0..8 keep their meaning.
-- NIR/SWIR are visible-light camera approximations, not spectral simulation.
local M={max=15,count=16}
M.modes={
    [0]={name='Off'},
    [1]={name='Starlight IR',exposure=2,gamma=1.2},
    [2]={name='NIR',exposure=1.25,gamma=1.15},
    [3]={name='White Hot',thermal=true},
    [4]={name='Black Hot',thermal=true},
    [5]={name='Rainbow',thermal=true},
    [6]={name='Ironbow',thermal=true},
    [7]={name='Lava',thermal=true},
    [8]={name='Graded Fire',thermal=true},
    [9]={name='Fusion',thermal=true,fusion=true},
    [10]={name='SWIR',exposure=.5,gamma=1.1},
    [11]={name='Red Hot / High Contrast',thermal=true},
    [12]={name='IR LED',exposure=.5,gamma=1.15,illuminator=true},
    [13]={name='Arctic',thermal=true},
    [14]={name='Sepia',thermal=true},
    [15]={name='Green Hot',thermal=true},
}
function M.valid(mode)return type(mode)=='number' and mode%1==0 and M.modes[mode]~=nil end
function M.needsTargets(mode)return M.valid(mode) and M.modes[mode].thermal==true end
return M
