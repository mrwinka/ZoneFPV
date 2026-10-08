-- PlayerController's projection can still use the previous camera cache in
-- our EngineTick pre-callback. Calibrate that native lens once, then project
-- all targets through the current CameraActor pose from the same frame.
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
local function identity(o)
    if not valid(o)then return end
    local address=call(o,'GetAddress')
    if finite(address) and address>0 and address%1==0 then return address end
end
local function point(v)
    local x,y,z=read(v,'X'),read(v,'Y'),read(v,'Z')
    if finite(x) and finite(y) and finite(z) and math.max(math.abs(x),math.abs(y),math.abs(z))<=1e12 then
        return {X=x,Y=y,Z=z}
    end
end
local function rotation(v)
    local p,y,r=read(v,'Pitch'),read(v,'Yaw'),read(v,'Roll')
    if finite(p) and finite(y) and finite(r)then return {Pitch=p%360,Yaw=y%360,Roll=r%360}end
end
local function lens(v)return finite(v) and v>1 and v<179 end
local function basis(r)
    local p,y,t=math.rad(r.Pitch),math.rad(r.Yaw),math.rad(r.Roll)
    local cp,sp,cy,sy,cr,sr=math.cos(p),math.sin(p),math.cos(y),math.sin(y),math.cos(t),math.sin(t)
    -- Unreal's X-forward, Y-right, Z-up basis; positive pitch looks up and
    -- positive roll turns the right axis down. No Euler singularity branch.
    return {X=cp*cy,Y=cp*sy,Z=sp},
        {X=sr*sp*cy-cr*sy,Y=sr*sp*sy+cr*cy,Z=-sr*cp},
        {X=-(cr*sp*cy+sr*sy),Y=sr*cy-cr*sp*sy,Z=cr*cp}
end
local function unchangedPoint(a,b)
    return a and b and math.abs(a.X-b.X)<=1e-6 and math.abs(a.Y-b.Y)<=1e-6 and math.abs(a.Z-b.Z)<=1e-6
end
local function unchangedRotation(a,b)
    if not a or not b then return false end
    for _,k in ipairs({'Pitch','Yaw','Roll'})do if math.abs((a[k]-b[k]+180)%360-180)>1e-6 then return false end end
    return true
end
local function snapshot(s)
    local pc,camera=read(s,'pc'),read(s,'camera')
    local pcID,cameraID=identity(pc),identity(camera)
    if not pcID or not cameraID then return nil,'camera_objects_unavailable' end
    if identity(call(pc,'GetViewTarget'))~=cameraID then return nil,'view_target_not_camera' end
    local manager,component=read(pc,'PlayerCameraManager'),read(camera,'CameraComponent')
    local managerID,componentID=identity(manager),identity(component)
    if not managerID or not componentID then return nil,'camera_components_unavailable' end
    local cachedPosition=point(call(manager,'GetCameraLocation'))
    local cachedRotation=rotation(call(manager,'GetCameraRotation'))
    local position=point(call(camera,'K2_GetActorLocation'))
    local orientation=rotation(call(camera,'K2_GetActorRotation'))
    local cachedFOV,currentFOV=call(manager,'GetFOVAngle'),read(component,'FieldOfView')
    if not cachedPosition or not cachedRotation or not position or not orientation then return nil,'camera_pose_unavailable' end
    if not lens(cachedFOV) or not lens(currentFOV) then return nil,'camera_lens_unavailable' end
    -- The cache's lens must match the current mount. Do not display a stale
    -- lens during FOV changes or force a second CameraManager update.
    if math.abs(cachedFOV-currentFOV)>.001 then return nil,'camera_lens_pending' end
    return {pcID=pcID,cameraID=cameraID,managerID=managerID,componentID=componentID,
        cachedPosition=cachedPosition,cachedRotation=cachedRotation,
        position=position,orientation=orientation,cachedFOV=cachedFOV,currentFOV=currentFOV}
end
local function unchanged(a,b)
    return b and a.pcID==b.pcID and a.cameraID==b.cameraID and a.managerID==b.managerID and a.componentID==b.componentID
        and unchangedPoint(a.cachedPosition,b.cachedPosition) and unchangedPoint(a.position,b.position)
        and unchangedRotation(a.cachedRotation,b.cachedRotation) and unchangedRotation(a.orientation,b.orientation)
        and math.abs(a.cachedFOV-b.cachedFOV)<=1e-6 and math.abs(a.currentFOV-b.currentFOV)<=1e-6
end
function M.new(s,nativeProject)
    if type(nativeProject)~='function'then return nil,'native_projection_unavailable' end
    local state,reason=snapshot(s)
    if not state then return nil,reason end
    local forward,right,up=basis(state.cachedRotation)
    local function probe(depth,horizontal,vertical)
        local p=state.cachedPosition
        local world={X=p.X+forward.X*depth+right.X*horizontal+up.X*vertical,
            Y=p.Y+forward.Y*depth+right.Y*horizontal+up.Y*vertical,
            Z=p.Z+forward.Z*depth+right.Z*horizontal+up.Z*vertical}
        local ok,x,y=pcall(nativeProject,world)
        if ok and finite(x) and finite(y) then return x,y end
    end
    local distance=1000 -- Centimetres; these samples query projection, not visibility/occlusion.
    local x0,y0=probe(distance,0,0)
    local xr,yr=probe(distance,distance,0)
    local xu,yu=probe(distance,0,distance)
    if not x0 or not xr or not xu then return nil,'native_calibration_failed' end
    local rx,ry,ux,uy=xr-x0,yr-y0,xu-x0,yu-y0
    local determinant=rx*uy-ux*ry
    if not finite(determinant) or math.abs(determinant)<1e-8 or math.max(math.abs(rx),math.abs(ry),math.abs(ux),math.abs(uy))>1000
        or math.abs(x0)>2 or math.abs(y0)>2 then return nil,'native_calibration_degenerate' end
    -- Validate perspective at independent depths and both screen axes. This
    -- fails closed for orthographic, inconsistent or nonlinear projections.
    for _,v in ipairs({{2,.35,.2},{.5,-.1,.3}})do
        local x,y=probe(distance*v[1],distance*v[2],distance*v[3])
        if not x then return nil,'native_calibration_failed' end
        local h,z=v[2]/v[1],v[3]/v[1]
        if math.abs(x-(x0+rx*h+ux*z))>1e-5 or math.abs(y-(y0+ry*h+uy*z))>1e-5 then
            return nil,'native_calibration_inconsistent'
        end
    end
    local after=snapshot(s)
    if not unchanged(state,after)then return nil,'camera_changed_during_calibration' end
    forward,right,up=basis(state.orientation)
    local position=state.position
    return function(world)
        local p=point(world)
        if not p then return end
        local x,y,z=p.X-position.X,p.Y-position.Y,p.Z-position.Z
        local depth=x*forward.X+y*forward.Y+z*forward.Z
        -- Never divide through the camera eye/near plane or mirror targets
        -- behind the mount into the visible screen.
        if not finite(depth) or depth<=1 then return end
        local h=(x*right.X+y*right.Y+z*right.Z)/depth
        local v=(x*up.X+y*up.Y+z*up.Z)/depth
        local sx,sy=x0+rx*h+ux*v,y0+ry*h+uy*v
        if finite(sx) and finite(sy)then return sx,sy,depth end
    end
end
return M
