freeslot("MT_FUZZ_THING", "S_FUZZ_THING1", "SPR_FUZZ")

mobjinfo[MT_FUZZ_THING] = {
	doomednum = 2999,
	spawnstate = S_FUZZ_THING1,
	spawnhealth = 1,
	radius = 16*FRACUNIT,
	height = 32*FRACUNIT,
	flags = MF_SOLID|MF_SHOOTABLE
}

addHook("MobjThinker", function(mo)
	if not (mo and mo.valid) then return end
	mo.momz = $1 + FRACUNIT/2
	mo.angle = $1 + ANG1*5
end, MT_FUZZ_THING)

addHook("PlayerThink", function(player)
	if player.mo and player.mo.valid and player.cmd.buttons & BT_JUMP then
		P_DoJump(player)
	end
end)
