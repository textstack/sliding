--[[
	Sliding - run and crouch to slide!
--]]

local EE = EE or {}

local function groundRotate(ply, ang)
	local tr = util.TraceLine({
		start = ply:GetPos(),
		endpos = ply:GetPos() - vector_up * 50,
		filter = ply
	})

	if not tr.Hit then return end

	ang:RotateAroundAxis(tr.HitNormal:Cross(ang:Up()), -90)
	ang.roll, ang.pitch = ang.pitch, -ang.roll
end

local vector_forward = Vector(1, 0, 0)
local vector_right = Vector(0, 1, 0)
hook.Add("Think", "EE_Sliding", function()
	for _, ply in player.Iterator() do
		local bone = ply:LookupBone("ValveBiped.Bip01_Pelvis")
		if not bone then continue end

		if not ply:GetNWBool("EE_Sliding") then
			ply.EE_SlideAng = ply.EE_SlideAng or angle_zero
			ply.EE_SlideAng = EE.DampenAngle(10, ply.EE_SlideAng, angle_zero)

			if pac then
				pac.ManipulateBoneAngles(ply, bone, ply.EE_SlideAng)
			else
				ply:ManipulateBoneAngles(bone, ply.EE_SlideAng)
			end

			if ply.EE_SlideSound then
				ply.EE_SlideSound:Stop()
				ply.EE_SlideSound1:Stop()
				ply.EE_SlidePlayingSound = false
			end

			continue
		end

		if not ply.EE_SlideSound then
			ply.EE_SlideSound = CreateSound(ply, "physics/body/body_medium_scrape_smooth_loop1.wav")
			ply.EE_SlideSound1 = CreateSound(ply, "physics/body/body_medium_scrape_rough_loop1.wav")
		end

		if not ply.EE_SlidePlayingSound then
			ply.EE_SlideSound:Play()
			ply.EE_SlideSound1:Play()
			EE_SlidePlayingSound = true
		end

		local vel = ply:GetVelocity()

		local ang = vel:Angle()
		local pitch = ang.pitch
		ang.pitch = 0

		if ply:OnGround() then
			groundRotate(ply, ang)

			local velLength = vel:Length()
			ply.EE_SlideSound:ChangeVolume(velLength * 0.0002)
			ply.EE_SlideSound:ChangePitch(40 + math.sqrt(velLength * 5))

			ply.EE_SlideSound1:ChangeVolume((velLength - 600) * 0.0001)
			ply.EE_SlideSound1:ChangePitch(20 + math.sqrt(velLength * 5))
		else
			ang.roll = ang.roll + pitch
			ply.EE_SlideSound:ChangeVolume(0)
			ply.EE_SlideSound1:ChangeVolume(0)
		end

		ang:RotateAroundAxis(vector_forward, -90)
		ang:RotateAroundAxis(vector_right, -ply:EyeAngles().yaw)
		ang:RotateAroundAxis(ang:Forward(), 45)

		ply.EE_SlideAng = ply.EE_SlideAng or angle_zero
		ply.EE_SlideAng = EE.DampenAngle(10, ply.EE_SlideAng, ang)

		if pac then
			pac.ManipulateBoneAngles(ply, bone, ply.EE_SlideAng)
		else
			ply:ManipulateBoneAngles(bone, ply.EE_SlideAng)
		end
	end
end)