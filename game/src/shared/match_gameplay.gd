extends RefCounted

## Match HTTP gameplay ids and the M6 1v1 seat → team map.
## Same contract as `backend/contracts/src/match_gameplay.ts`.
## TEAM_A=1 / TEAM_B=2 come from `BastionBlueprintBundle`; seats are 0 and 1.

const TRAPRUSH: String = "traprush"
const BASTION: String = "bastion"
const BASTION_SEATS: int = 2
const TEAM_A: int = 1
const TEAM_B: int = 2


static func is_id(value: String) -> bool:
	return value == TRAPRUSH or value == BASTION


static func team_id_for_seat(seat: int) -> int:
	if seat == 0:
		return TEAM_A
	if seat == 1:
		return TEAM_B
	return 0


static func seat_for_team_id(team_id: int) -> int:
	if team_id == TEAM_A:
		return 0
	if team_id == TEAM_B:
		return 1
	return -1
