--[[
	Sliding - run and crouch to slide!
--]]

local EE = EE or {}
require("greatzenkakuman/predicted")
local predicted = greatzenkakuman.predicted

local wallCheckVec = Vector()
local function makeNormal(ply)
	local startPos = ply:GetPos()

	local tr = util.TraceEntity({
		start = startPos,
		endpos = startPos - vector_up * 10,
		filter = ply
	}, ply)

	if not tr.Hit then return end

	wallCheckVec.x, wallCheckVec.y = tr.HitNormal.x, tr.HitNormal.y
	wallCheckVec:Normalize()

	local tr1 = util.TraceEntity({
		start = startPos,
		endpos = startPos + wallCheckVec * 10,
		filter = ply
	}, ply)

	if tr1.Hit then return end

	return tr.HitNormal
end

sound.Add {
	name = "Sliding.ImpactSoft",
	channel = CHAN_BODY,
	level = 75,
	volume = 0.6,
	sound = {
		"physics/body/body_medium_impact_soft1.wav",
		"physics/body/body_medium_impact_soft2.wav",
		"physics/body/body_medium_impact_soft5.wav",
		"physics/body/body_medium_impact_soft6.wav",
		"physics/body/body_medium_impact_soft7.wav",
	},
}

local poseAng = Angle(0, -90, 0)
hook.Add("UpdateAnimation", "EE_Sliding", function(ply)
	if not ply:GetNWBool("EE_Sliding") then return end

	local vel = ply:GetVelocity()
	vel:Normalize()

	local aim = ply:GetAimVector()
	aim:Rotate(poseAng)

	ply:SetPoseParameter("aim_yaw", vel:Dot(aim) * 90)
end)

local gravityCvar = GetConVar("sv_gravity")
local maxVelocityCvar = GetConVar("sv_maxvelocity")
local rotAng = Angle()
local slideVel = Vector()
local desiredDir = Vector()
local oldVel = Vector()
local function handleSliding(ply, mv, pr)
	local frameTime = FrameTime()
	local vel = pr.Get("EE_SlideVel", slideVel)
	local length2D = math.sqrt(vel.x^2 + vel.y^2)

	desiredDir.x, desiredDir.y = 0, 0

	if mv:KeyDown(IN_MOVELEFT) then
		desiredDir.x = 1
	end
	if mv:KeyDown(IN_MOVERIGHT) then
		desiredDir.x = desiredDir.x - 1
	end
	if mv:KeyDown(IN_FORWARD) then
		desiredDir.y = -1
	end
	if mv:KeyDown(IN_BACK) then
		desiredDir.y = desiredDir.y + 1
	end

	if desiredDir.x ~= 0 or desiredDir.y ~= 0 then
		if desiredDir.x ~= 0 and desiredDir.y ~= 0 then
			desiredDir:Mul(0.707106781)
		end

		rotAng.yaw = ply:EyeAngles().yaw
		desiredDir:Rotate(rotAng)

		local sideDot = (desiredDir.x * vel.x + desiredDir.y * vel.y) / length2D

		if sideDot > 0.05 then
			rotAng.yaw = frameTime * 50
			vel:Rotate(rotAng)
		elseif sideDot < -0.05 then
			rotAng.yaw = -frameTime * 50
			vel:Rotate(rotAng)
		end
	end

	local gravity = gravityCvar:GetFloat()

	local hitNormal = makeNormal(ply)
	if hitNormal then
		local slopeMult = 2
		if hitNormal.x * vel.x + hitNormal.y * vel.y > 0 then
			slopeMult = slopeMult * 1.5
		end

		vel.x = vel.x + hitNormal.x * gravity * frameTime * slopeMult
		vel.y = vel.y + hitNormal.y * gravity * frameTime * slopeMult
	end

	if ply:OnGround() then
		local speedUp = math.max(math.abs(pr.Get("EE_OldVel", oldVel).z) - gravity * 0.5, 0)
		vel.x = vel.x + speedUp * (vel.x / length2D)
		vel.y = vel.y + speedUp * (vel.y / length2D)

		if speedUp > 0 then
			pr.EmitSound(ply:GetPos(), "Sliding.ImpactSoft")
		end
	end

	vel.x = EE.Dampen(0.1, vel.x, 0, frameTime)
	vel.y = EE.Dampen(0.1, vel.y, 0, frameTime)

	local maxVelocity = maxVelocityCvar:GetFloat()
	vel.x = math.Clamp(vel.x, -maxVelocity, maxVelocity)
	vel.y = math.Clamp(vel.y, -maxVelocity, maxVelocity)
	vel.z = mv:GetVelocity().z

	pr.Set("EE_SlideVel", vel)
	mv:SetVelocity(vel)
	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)
end

local function handleSlideAttempt(ply, mv, pr)
	if mv:KeyPressed(IN_DUCK) and not pr.Get("EE_Sliding") then
		pr.Set("EE_TryingToSlide", true)
	end

	if mv:KeyReleased(IN_DUCK) then
		pr.Set("EE_Sliding", false)
		pr.Set("EE_TryingToSlide", false)
	end

	if not pr.Get("EE_TryingToSlide") then return end
	if not ply:OnGround() then return end

	pr.Set("EE_TryingToSlide", false)

	if ply:WaterLevel() > 1 or pr.Get("EE_OldVel", oldVel):Length() < ply:GetRunSpeed() * 0.75 then return end

	pr.Set("EE_Sliding", true)
	pr.Set("EE_SlideVel", mv:GetVelocity())
end

hook.Add("SetupMove", "EE_Sliding", function(ply, mv)
	predicted.Process("SlidingAbility", function(pr)
		local curVel = mv:GetVelocity()

		handleSlideAttempt(ply, mv, pr)

		if pr.Get("EE_Sliding") then
			handleSliding(ply, mv, pr)
		end

		ply:SetNWBool("EE_Sliding", pr.Get("EE_Sliding"))
		pr.Set("EE_OldVel", curVel)
	end)
end)

hook.Add("PlayerFootstep", "EE_Sliding", function(ply)
	if ply:GetNWBool("EE_Sliding") then return true end
end)

local calcIdeals = {
	pistol = ACT_HL2MP_SIT_PISTOL,
	revolver = ACT_HL2MP_SIT_PISTOL,
	duel = "sit_duel",
	smg = ACT_HL2MP_SIT_SMG1,
	ar2 = ACT_HL2MP_SIT_AR2,
	shotgun = ACT_HL2MP_SIT_SHOTGUN,
	rpg = ACT_HL2MP_SIT_RPG,
	physgun = ACT_HL2MP_SIT_PHYSGUN,
	crossbow = ACT_HL2MP_SIT_CROSSBOW,
	camera = "sit_camera",
	slam = ACT_HL2MP_SIT_SLAM,
	normal = ACT_HL2MP_SIT,
	grenade = ACT_HL2MP_SIT_GRENADE,
	melee = ACT_HL2MP_SIT_MELEE,
	melee2 = "sit_melee2",
	knife = "sit_knife",
	fist = ACT_HL2MP_SIT_FIST,
	passive = "sit_passive",
	magic = ACT_HL2MP_SIT_PISTOL
}

hook.Add("CalcMainActivity", "EE_Sliding", function(ply)
	if not ply:GetNWBool("EE_Sliding") then return end

	ply.CalcIdeal = ACT_HL2MP_SIT
	ply.CalcSeqOverride = -1

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return ply.CalcIdeal, ply.CalcSeqOverride end

	if wep.HoldType then
		ply.CalcIdeal = calcIdeals[string.lower(wep.HoldType)] or ply.CalcIdeal
	else
		ply.CalcIdeal = calcIdeals[string.lower(wep:GetHoldType())] or ply.CalcIdeal
	end

	if type(ply.CalcIdeal) == "string" then
		ply.CalcIdeal = ply:GetSequenceActivity(ply:LookupSequence(ply.CalcIdeal))
	end

	return ply.CalcIdeal, ply.CalcSeqOverride
end)

---Smooths out the changes of a realtime-updated value
-- inputs:
--   speed - number representing how fast the output value changes, higher is faster
--   from - the starting value, should be set as this function's output from the previous frame
--   to - the raw input
--   frameTime - custom frametime if needed
-- returns:
--   the from value shifted a little bit towards the to value
function EE.Dampen(speed, from, to, frameTime)
	return Lerp(1 - math.exp(-speed * (frameTime or FrameTime())), from, to)
end

---Smooths out the changes of a realtime-updated angle
-- inputs:
--   speed - number representing how fast the output value changes, higher is faster
--   from - the starting value, should be set as this function's output from the previous frame
--   to - the raw input
-- returns:
--   the from value shifted a little bit towards the to value
function EE.DampenAngle(speed, from, to)
	return LerpAngle(1 - math.exp(-speed * FrameTime()), from, to)
end