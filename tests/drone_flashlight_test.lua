local function object(t)
    t=t or {};function t:IsValid()return not self.dead end;return t
end
local function engineClass(name,super)
    return object({IsAnyClass=function()return true end,GetFName=function()return {ToString=function()return name end}end,
        GetFullName=function()return 'Class /Script/Engine.'..name end,GetSuperStruct=function()return super end})
end
local class=engineClass('SpotLightComponent')
local nativeLight=object({GetClass=function()return class end})
local lookups,discoveries=0,0
-- Reproduce the actual v39 log: the unused SpotLight actor class is absent.
-- The native spotlight component is present but path lookup also misses it.
StaticFindObject=function(path)
    assert(path=='/Script/Engine.SpotLightComponent' or path=='/Script/Engine:SpotLightComponent',
        'flashlight must not depend on the absent SpotLight actor class')
    lookups=lookups+1;return nil
end
FindFirstOf=function(name)assert(name=='SpotLightComponent');discoveries=discoveries+1;return nativeLight end
FName=function(value)return value end
local M=dofile('mod/Scripts/drone_flashlight.lua')
local camera=object({CameraComponent=object(),bHidden=true})
local s={camera=camera,world=object()}
local lamps={};local failure
local gameplay=object({BeginDeferredActorSpawnFromClass=function()error('absent native SpotLight actor must not be spawned')end})
local function identity(transform)
    assert(transform.Translation.X==0 and transform.Translation.Y==0 and transform.Translation.Z==0
        and transform.Rotation.X==0 and transform.Rotation.Y==0 and transform.Rotation.Z==0 and transform.Rotation.W==1
        and transform.Scale3D.X==1 and transform.Scale3D.Y==1 and transform.Scale3D.Z==1)
end
function camera:AddComponentByClass(kind,manual,transform,deferred)
    assert(kind==class and manual==true and deferred==true);identity(transform)
    local light=object({owner=self,registered=false})
    for _,name in ipairs({'SetMobility','SetIntensity','SetAttenuationRadius','SetInnerConeAngle','SetOuterConeAngle','SetCastShadows'})do
        light[name]=function(self,value)
            assert(not self.registered,'configure deferred component before registration')
            if failure==name then error(name)end;self[name..'Value']=value
        end
    end
    function light:K2_DestroyComponent(owner)
        assert(owner==camera and self.owner==camera);self.dead=true;self.destroyed=(self.destroyed or 0)+1
    end
    function light:SetVisibility(value,propagate)assert(propagate==false);self.visible=value end
    function light:SetHiddenInGame(value,propagate)assert(propagate==false);self.hidden=value end
    function light:K2_AttachToComponent(parent,socket,l,r,sc,weld)
        assert(parent==camera.CameraComponent and socket=='None' and l==0 and r==0 and sc==0 and not weld)
        self.parent=parent;return failure~='attach'
    end
    lamps[#lamps+1]=light;return light
end
function camera:FinishAddComponent(component,manual,transform)
    assert(component.owner==self and manual==true and component.parent==self.CameraComponent);identity(transform)
    if failure=='finish' then error('registration failed')end
    component.registered=true
end
function camera:SetActorHiddenInGame(value)self.bHidden=value end
assert(not M.set(nil,true,gameplay));M.restore(nil)
assert(M.toggle(s,gameplay) and s.flashlightEnabled and #lamps==1)
local first=lamps[1]
assert(first.parent==camera.CameraComponent and first.registered and first.SetIntensityValue==5000
    and first.visible and not first.hidden and camera.bHidden==false,
    'actual light is registered, visible, attached along camera direction and owner is visible')
assert(lookups==2 and discoveries==1,'fall back to existing native component class when path lookup misses')
assert(M.set(s,true,gameplay) and #lamps==1,'repeated on does not allocate additional lamps')
s.vision={mode=12,illuminator=object()}
assert(M.toggle(s,gameplay) and not s.flashlightEnabled and first.destroyed==1 and s.vision.illuminator:IsValid()
    and camera.bHidden==true,'visible flashlight never destroys separate sensor IR lamp and restores owned camera state')
assert(nativeLight:IsValid(),'native character light is used only for class identity and never altered')
for _,problem in ipairs({'SetIntensity','attach','finish'})do
    failure=problem;assert(not M.set(s,true,gameplay))
    assert(not s.flashlightEnabled and not s.flashlight and lamps[#lamps].destroyed==1 and camera.bHidden==true)
end
failure=nil;assert(M.set(s,true,gameplay));local last=lamps[#lamps]
M.restore(s);M.restore(s);assert(last.destroyed==1 and not s.flashlightEnabled and not s.flashlight)
assert(lookups==2 and discoveries==1,'resolved class is cached across toggles, with no per-frame discovery')
-- Direct native class lookup takes the cheaper path when available.
StaticFindObject=function(path)assert(path=='/Script/Engine.SpotLightComponent');return class end
FindFirstOf=function()error('no global discovery when exact native class is available')end
M=dofile('mod/Scripts/drone_flashlight.lua');assert(M.toggle(s,gameplay));M.restore(s)
-- A failed lookup leaves no object allocated or enabled; a later toggle can
-- retry after the game's native flashlight component has streamed in.
StaticFindObject=function()return nil end;FindFirstOf=function()return nil end
M=dofile('mod/Scripts/drone_flashlight.lua');local count=#lamps
assert(not M.set(s,true,gameplay) and #lamps==count and not s.flashlightEnabled)
FindFirstOf=function()return object({dead=true,GetClass=function()error('invalid UObject must never reach GetClass')end})end
assert(not M.set(s,true,gameplay) and #lamps==count and not s.flashlightEnabled,
    'null native wrappers are rejected before class access')
FindFirstOf=function()return nativeLight end
assert(M.set(s,true,gameplay));M.restore(s)
print('PASS absent SpotLight actor class recovery, camera-owned spotlight registration/direction/visibility, class caching, IR independence and rollback/teardown')
