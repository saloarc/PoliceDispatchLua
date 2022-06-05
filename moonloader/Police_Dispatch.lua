-- encoding: cyrillic (windows 1251)
script_name('PD Radio')
script_author('donaks')
script_url("github.com/don-aks/PoliceDispatchLua/")
script_version('2.1.1-patch')
script_version_number(6)
script_properties("work-in-pause")

require 'lib.moonloader'
local download_status = require('lib.moonloader').download_status
local inicfg = require 'inicfg'
local memory = require 'memory'

-- ���� ��� 027
package.path = package.path..";"..getWorkingDirectory().."\\?.lua"

require 'config.PoliceDispatch.config'

local DISP_IS_SPEAK = false
local VARS = {}
local MAP_ICONS = {}
local CFG, INI

local TIME_ENTER_AFK
local IS_CLEAN_QUEUE = false


function chatMessage(text)
	return sampAddChatMessage("[PD Radio v"..thisScript().version.."]: {ffffff}"..text, 0xFF3523)
end

local v = getMoonloaderVersion()
if v < 26 then
	chatMessage("���� ������ moonloader �� ��������������. ���������� 026-beta ��� ����.")
	chatMessage("������ �� ���������� ����� ����� ������: https://www.blast.hk/threads/13305/")
	thisScript():unload()
	return
end

local res, sampev = pcall(require, 'lib.samp.events')
if not res then
	chatMessage("���������� SAMP.LUA! {32B4FF}blast.hk/threads/59503{FFFFFF}.")
	thisScript():unload()
	return
end

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	while sampGetCurrentServerName() == 'SA-MP' do wait(100) end

	-- ��������� .json
	local f = io.open(PATH.config.."config.json", 'r')
	-- ������� �����������
	local f_text = f:read('*a'):gsub("//[^\n]+", ''):gsub("/%*(.-)%*/", '')

	res, CFG = pcall(decodeJson, f_text)
	if not res then
		local f = io.open(PATH.config.."json_err.log", 'w')
		f:write(f_text)
		f:close()

		print("����� .json �����, ������� ����� ������ ��������� � moonloader/config/PoliceDispatch/json_err.log")
		chatMessage("�� ������� ������� .json ����! ����������� � moonloader.log.")

		decodeJson(f_text)
		thisScript():unload()
		return
	end
	f:close()

	if not CFG then
		local f = io.open(PATH.config.."json_err.log", 'w')
		f:write(f_text)
		f:close()

		print("����� .json �����, ������� ����� ������ ��������� � moonloader/config/PoliceDispatch/json_err.log")
		chatMessage("�� ������� ������� .json ����! ����������� � moonloader.log.")
		thisScript():unload()
		return
	end


	local serverName = sampGetCurrentServerName()
	local ip, port = sampGetCurrentServerAddress()
	local serverIP = ip..":"..port

	local isFindServer = false
	-- ������ ������� �������
	for _, server in ipairs(CFG.servers) do
		if server.server.ip == serverIP or serverName:find(server.server.name, 1, true) then
			-- ��������� ������� config �
			-- ������ ������� ��� ��������
			-- CFG -> config, call, find ...
			local c = server
			c.config = CFG.config
			CFG = c

			isFindServer = true
			break
		end
	end

	if not isFindServer then
		print("������� ������� �� ������� � �������. �������� ������ �������.")
		thisScript():unload()
		return
	end

	-- ��������� .ini
	INI = inicfg.load({
		INI={
			state=true,
			isCheckUpdates=true,
			soundInAFK=false,
			callsVolume=3,
			findVolume=3,
			radioVolume=3,
			userVolume=3
		}
	}, PATH.ini)

	-- ���������� ���������/���������� 
	-- ���������������� �������
	local tUser = {}
	if CFG.user then
		for i, it in ipairs(CFG.user) do
			tUser[i] = true
		end
	end

	local keyServer = CFG.name.."_UserEvents"
	if #tUser > 0 then
		if not INI[keyServer] or #tUser ~= #INI[keyServer] then
			INI[keyServer] = tUser
		end
	end

	saveIni()

	checkUpdates()
	sampRegisterChatCommand('pdradio', mainMenu)

	if INI.INI.state then
		chatMessage("��������. ���������� ��������: {32B4FF}/pdradio{FFFFFF}. �����: {32B4FF}vk.com/donaks{FFFFFF}.")
	else
		chatMessage("��������! ���������� ��������: {32B4FF}/pdradio{FFFFFF}. �����: {32B4FF}vk.com/donaks{FFFFFF}.")
	end

	local radioVol = memory.read(0xBA6798, 1)
	if INI.INI.state and radioVol == 0 then
		chatMessage("��������! �������� ����� � ���������� ��� ����, ����� ������ ��������� � ����������� � ����, ���� ���� �� ��������.")
	end


	while true do
		wait(20)
		checkDialogsRespond()

		if not soundInAFK then
			if not TIME_ENTER_AFK and isGamePaused() then
				TIME_ENTER_AFK = os.clock()
			elseif TIME_ENTER_AFK and not isGamePaused() then
				TIME_ENTER_AFK = nil
			end
		end
	end
end



function sampev.onServerMessage(color, message)
	if not INI or not CFG or not INI.INI.state then return true end

	-- � ����. ����� ���������� ����������� �����, ��� ��������
	-- ��������� �� ���� ����� ������ �� ���.
	if not soundInAFK and TIME_ENTER_AFK and os.clock() - TIME_ENTER_AFK >= 120 then
		return true
	end

	handleEvent(message, color)
	return true
end




-- MAIN FUNCTION --

-- HANDLER EVENTS --
function handleEvent(str, color)
	local ev, pattern, markerId, idUserEvent = getEventInfo(str, color)
	if not ev then
		-- �������, ������ ��� ���� ������ ���� �� ��������� ������
		if #VARS > 0 then
			VARS = {}
		end
		return false, 'not ev'
	end

	local vars = getVariablesFromMessage(str, pattern)
	-- ������ ������� �� ���������� VARS �� ����������� ������.
	vars = concatWithGlobalVars(vars, ev)

	if ev == 'find' then
		if INI.INI.findVolume == 0 then return false, 'volume' end
		-- ���� ��� ������������� ���������
		if not vars.area then
			if markerId then
				vars.area = getMarkerArea(markerId)
				if not vars.area then
					print("������ �� ����� � id "..markerId.." � ������ find �� �������.")
					return false
				end
			elseif type(CFG.find.pattern) == 'table' and #CFG.find.pattern > 1 then
				-- ��������� ������ �� �����
				VARS['find'] = vars
				return true
			else
				print("������! ��������� @area �� ������� � ������ find!")
				print("������� markerId ��� @area � ��������� � ������������� ������!")
				return false
			end
		end

		vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)

		if CFG.find.vehOnFoot and vars.vehname == CFG.find.vehOnFoot then
			vars.onFoot = true
		elseif vars.nick or vars.id then
			-- ����� ���� �� ���� ������ �� ������ ������
			local playerId = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
			local playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(playerId)

			if playerInStream and isCharInAnyCar(playerHandle) then
				local carHandle = storeCarCharIsInNoSave(playerHandle)
				vars.vehid = getCarModel(carHandle)
				vars.vehcolor, _ = getCarColours(carHandle)
			end
		end

	elseif ev == 'call' then
		if INI.INI.callsVolume == 0 then return false, 'volume' end
		if not vars.area or not vars.text then
			if type(CFG.call.pattern) == 'table' and #CFG.call.pattern > 1 then
				VARS['call'] = vars
				return true
			else
				print("������! ���������� @area ��� @text �� ������� � ������ call!")
				return false
			end
		end

		if inArray(vars.text, CFG.config.stopWords) then
			return false, 'stopWords'
		end

		if 		CFG.call.isPlayGangActivity and
				inArray(str, CFG.config.dictionaryGangActivity) and
				varInElementsArray(vars.area, GANG_ACTIVITY_SOUNDS)
		then
			ev = 'gangActivity'
		elseif 	math.random(2) == 2 and
				varInElementsArray(vars.area, AREA_AND_CODE_SOUNDS) 
		then
			math.randomseed(os.time())
			ev = 'areaAndCode'
		end

	elseif ev == 'radio' then
		if INI.INI.radioVolume == 0 then return false, 'volume' end
		if CFG.radio.isPlayShotsFired then
			if inArray(vars.text, CFG.config.code0Words) then
				ev = 'code0'
			elseif inArray(vars.text, CFG.config.code1Words) then
				ev = 'code1'
			end
		end

		-- ���������������� ������ �� �����
		if 	ev == 'radio' and
			type(CFG.radio.userMessages) == "table" and
			#CFG.radio.userMessages > 0
		then
			for _, usermsg in ipairs(CFG.radio.userMessages) do
				if inArray(vars.text, toTable(usermsg.textFind), usermsg.useRegexInPattern) then
					local sounds = cloneTable(toTable(usermsg.sounds))

					for i, sound in ipairs(sounds) do
						if sound == "@cityplayer" then
							sounds[i] = getAreaSoundPatch(getPlayerCity(PLAYER_PED))
						elseif sound == "@areaplayer" then
							sounds[i] = getAreaSoundPatch(getPlayerArea(PLAYER_PED))
						elseif varname == "@randomtencode" then
							sounds[i] = randomChoice(DISPATCH_SOUNDS.codes)
						elseif varname == "@randomtencodewithin" then
							sounds[i] = randomChoice(DISPATCH_SOUNDS.codesWithIn)
						elseif varname == "@randomarea" then
							sounds[i] = getAreaSoundPatch(randomChoice(AREAS)[1])
						elseif varname == "@randomareaincityplayer" then
							local city = getPlayerCity(PLAYER_PED)
							if not city or city == "San Andreas" then
								-- � �������� ��������� �����
								sounds[i] = getAreaSoundPatch(randomChoice(AREAS)[1])
							else
								sounds[i] = getAreaSoundPatch(
									randomChoice(LIST_AREAS_IN_REGIONS[city])
								)
							end
						elseif varname == "@codezero" then
							sound = randomChoice(CODE_0_SOUNDS)
						elseif varname == "@codeone" then
							sound = randomChoice(CODE_1_SOUNDS)
						else
							sounds[i] = PATH.audio..sound:gsub('/', '\\')
						end
					end

					lua_thread.create(
						playSounds,
						sounds,
						'radioVolume',
						usermsg.isPlayRadioOn
					)
					return
				end
			end
			return false, 'not ev'
		elseif inArray(vars.text, QUESTION_WORDS) then
			return false, 'question words'
		elseif ev == 'radio' then
			return false, 'text radio'
		end

	elseif ev == 'user' then
		if INI.INI.userVolume == 0 then return false, 'volume' end
		local arrSounds = parceSounds(idUserEvent, vars)
		if type(arrSounds) == 'table' and #arrSounds > 0 then
			lua_thread.create(playSounds, arrSounds, 'userVolume', CFG.user[idUserEvent].isPlayRadioOn)
			return
		else
			print('��������� ������ � ������� "sounds" � ���������������� ������ '..CFG.user[idUserEvent].name..', ���� �� �� ��������.!')
			return false
		end
	end

	return playDispatch(ev, vars)
end

function getVariablesFromMessage(message, pattern)
	-- ���������� ������ {var: value}
	local varsAndValues = {}
	local vars = {}

	-- ���� ��� @var
	local start = 1
	local var
	for _ = 1, #message do
		_, start, var = pattern:find("@([%a_]+)", start)
		if var then
			table.insert(vars, var)
		else
			break
		end
	end

	for _, var in ipairs(vars) do
		local patternFindVar = "(.+)"
		if var == 'n' or var == 'id' then
			patternFindVar = "(%%d+)"
		end

		local patternWithoutVar = pattern:gsub(
			"@"..var.."[^%a_]",
			patternFindVar..(pattern:match("@"..var.."([^%a_])") or "")
		):gsub("@([%a_]+)", '.+')

		varsAndValues[var] = message:match(patternWithoutVar)

		if not varsAndValues[var] then
			print("Warning: �� ������� ���������� @"..var.." � ������ \""..message.."\"!")
		end
	end

	return varsAndValues
end

function concatWithGlobalVars(vars, event)
	if VARS[event] then
		local t = concatTablesWithKeys(vars, VARS[event])
		VARS[event] = {}
		return t
	end
	return vars
end




-- GET EVENT --

function getEventInfo(str, color)
	local ev, patt, idUserEvent = getEventAndPattern(str, color)
	if ev == false then return end
	local markerId = CFG[ev].markerId

	return ev, patt, markerId, idUserEvent
end

function getEventAndPattern(str, color)
	-- �� ��������� user ������ ����������� ������ �������, ���� �� ������ �����.
	if not CFG.userNotPriority then
		local userPattern, idUserEvent = getUserPatternAndId(str, color)
		if userPattern then
			return 'user', userPattern, idUserEvent
		end
	end

	for _, key in ipairs({'call', 'find', 'radio'}) do
		if CFG[key] then
			local patterns = CFG[key].pattern
			local colors = CFG[key].color

			patterns = toTable(patterns)
			colors = toTable(colors)

			local isColor = true
			for _, col in pairs(colors) do
				if col ~= tonumber(color) then
					isColor = false
				else
					isColor = true
					break
				end
			end
			
			if isColor then
				for _, patt in ipairs(patterns) do
					if not CFG[key].useRegexInPattern then
						patt = '^'..esc(patt)
					end
					local pattWithoutVars = getPatternWithoutVars(patt)
					if str:find(pattWithoutVars) then
						return key, patt
					end
				end
			end
		end
	end

	if CFG.userNotPriority then
		local userPattern, idUserEvent = getUserPatternAndId(str, color)
		if userPattern then
			return 'user', userPattern, idUserEvent
		end
	end

	return false
end

function getUserPatternAndId(str, color)
	-- user events
	if not CFG.user or #CFG.user == 0 then
		return false
	end

	for i, ev in ipairs(CFG.user) do
		if INI[CFG.name.."_UserEvents"][i] then
			local patterns = ev.pattern
			local colors = ev.color

			patterns = toTable(patterns)
			colors = toTable(colors)

			local isColor = true
			for _, col in pairs(colors) do
				if col ~= tonumber(color) then
					isColor = false
				else
					isColor = true
					break
				end
			end

			if isColor then
				for _, patt in ipairs(patterns) do
					if not ev.useRegexInPattern then
						patt = '^'..esc(patt)
					end

					local pattWithoutVars = getPatternWithoutVars(patt)
					if str:find(pattWithoutVars) then
						return patt, i
					end
				end
			end
		end
	end
end

function getPatternWithoutVars(pattern)
	return pattern:gsub("@([%a_]+)", ".+")
end




-- PARCE USER SOUNDS FROM CONFIG FILE --

function parceSounds(idUserEvent, vars)
	local arrSounds = {}
	local CFGuser = CFG.user[idUserEvent]
	CFGuser.sounds = toTable(CFGuser.sounds)
	for i, sound in ipairs(CFGuser.sounds) do

		if type(sound) ~= 'string' then
			print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
			print("���������������� ����� ������ ���� ����� ���������!")
			return false

		-- DISP.key1.key2
		elseif sound:find("^DISP%.") then
			local s = sound:split('%.')
			if #s == 2 or #s == 3 then
				local newSound
				if #s == 3 then
					if s[2] == 'codes' or s[2] == 'codesWithIn' then
						s[3] = tonumber(s[3])
					end
					newSound = DISPATCH_SOUNDS[s[2]][s[3]]
				else
					newSound = DISPATCH_SOUNDS[s[2]]
				end

				if not newSound then
					print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
					print("���� �� ������! ��������� ��� �� ��� ����� ��������.")
					print("�������� ���� ����� � ������� � ���������� DISPATCH_SOUNDS � ����� config.lua.")
					print("������� �������� ����� ��������!")
					return false
				end
				sound = newSound
			else
				print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
				print("��������� ���� �����: DISP.key1.key2. ������: DISP.words.headTo10.")
				return false
			end

		-- @var
		elseif sound:find("^@") then
			local varname = sound:match("@([%a_]+)")
			if not varname then
				print("������������ ���������� � ����� "..tostring(sound).." (�"..i..")"..
					" � user ������ '"..CFGuser.name.."'!")
				print("���������� ������� ������ ��������� ��� ������ ��������������!")
				return false
			end

			-- ���� ���������� ��� � ������.
			if 	(not vars[varname]) and 
				(not (CFGuser.vars and CFGuser.vars[varname])) and
				(varname ~= 'veh' or not (vars.vehname or vars.vehid))
			then
				if varname == 'area' and CFGuser.markerId then
					local markerId = CFGuser.markerId
					local area = getMarkerArea(markerId)
					if not area then
						print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("������ �� ����� � id "..markerId.." � ������ user �� �������.")
						return false
					end

					local newSound = getAreaSoundPatch(area)
					if not newSound then
						print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("@area �� �������.")
						return false
					end
					sound = newSound

				elseif varname == 'veh' then
					if vars.id or vars.nick then
						vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
						res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
						if res then
							for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
								table.insert(arrSounds, soundColor)
							end
							sound = getVehSound(vars.vehid)
						else
							print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
							print("���������� @vehname ��� @vehid ��� � ������!")
							print("� �����, ��������� � ���������� @id ��� @nick ��� ���� ������!")
							return false
						end
					else
						print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("���������� @vehname ��� @vehid ��� � ������!")
						return false
					end
				elseif varname == 'suspectveh' then
					-- ��������.
					if vars.id or vars.nick then
						vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
						res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
						if res then
							table.insert(arrSounds, DISPATCH_SOUNDS.suspect.suspect1)
							table.insert(arrSounds, DISPATCH_SOUNDS.words.onA)
							for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
								table.insert(arrSounds, soundColor)
							end
							sound = getVehSound(vars.vehid)
						else
							-- ��������������������
							-- �����.
							local playerInStream, playerHandle

							local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
							if id ~= playerId then
								playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(vars.id)
							else
								playerInStream, playerHandle = true, PLAYER_PED
							end

							if not playerInStream then
								print("Warning @suspectveh: ����� ��� ���� ������ � user ������ '"..CFGuser.name.."'!")
								sound = nil
							else
								table.insert(arrSounds, DISPATCH_SOUNDS.suspect.suspect1)
								sound = DISPATCH_SOUNDS.suspect.onFoot
							end
						end
					else
						print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("���������� @vehname ��� @vehid ��� � ������!")
						return false
					end
				elseif varname == "cityplayer" then
					local city = getPlayerCity(PLAYER_PED)
					if not city then
						local x, y, z = getCharCoordinates(PLAYER_PED)
						print("������! �� ������� ���������� ����� ������.")
						print("����������: x = "..x..", y = "..y..", z = "..z)
						return false
					end
					sound = getAreaSoundPatch(city)
				elseif varname == "areaplayer" then
					local area = getPlayerArea(PLAYER_PED)
					if not area then
						local x, y, z = getCharCoordinates(PLAYER_PED)
						print("������! �� ������� ���������� ����� ������.")
						print("����������: x = "..x..", y = "..y..", z = "..z)
						return false
					end
					sound = getAreaSoundPatch(area)
				elseif varname == "randomtencode" then
					sound = randomChoice(DISPATCH_SOUNDS.codes)
				elseif varname == "randomtencodewithin" then
					sound = randomChoice(DISPATCH_SOUNDS.codesWithIn)
				elseif varname == "randomarea" then
					sound = getAreaSoundPatch(randomChoice(AREAS)[1])
				elseif varname == "randomareaincityplayer" then
					local city = getPlayerCity(PLAYER_PED)
					if not city or city == "San Andreas" then
						-- � �������� ��������� �����
						sound = getAreaSoundPatch(randomChoice(AREAS)[1])
					else
						sound = getAreaSoundPatch(
							randomChoice(LIST_AREAS_IN_REGIONS[city])
						)
					end
				elseif varname == "codezero" then
					sound = randomChoice(CODE_0_SOUNDS)
				elseif varname == 'codeone' then
					sound = randomChoice(CODE_1_SOUNDS)
				else
					print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
					print("���������� @"..varname.." ��� � ������!")
					return false
				end

			-- ���� ����������� � ����������������� �������� ����������
			elseif
				CFGuser.vars and 
				(
					(CFGuser.vars[varname]) or (
						varname == 'veh' and
						-- ��� veh ������ ����������
						(CFGuser.vars['vehname'] or CFGuser.vars['vehid'])
					)
				)
			then
				if varname ~= 'veh' then
					-- ��������, ���� ����� ����� �� ��������� �������
					-- � ��������� ���������������� ����������.
					newSound = CFGuser.vars[varname] [vars[varname]]
					if newSound then
						sound = newSound
					else
						print("Warning! � vars."..varname.." ��� �������� "..vars[varname]..". "..
							"���������� �� ��������������.")
					end
				end

				-- ��������� �������� ���������� ��� �����.
				-- �� ���� �� �� ������� ��� � else ����.
				-- ����� ���������.
				-- � ����� ����������. ������� �� ���� ������.
				if varname == 'area' then
					local area = sound
					sound = getAreaSoundPatch(area)
					if not sound then
						print("������ � ����� '@area' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("����� ������ �� ���������������� �����������, ����� "..area.." �� ��� ������.")
						return false
					end
				elseif varname == 'veh' then
					if vars['vehname'] or vars['vehid'] then
						-- ��... ��� �� ���������.
						-- ������� �� ���� ������.
						-- � �� ����� ��?
						if CFGuser.vars['vehname'] then
							local newSound = CFGuser.vars.vehname[vars.vehname]
							if newSound then
								vars.vehname = newSound
							end
						end
						if CFGuser.vars['vehid'] then
							local newSound = CFGuser.vars.vehid[vars.vehid]
							if newSound then
								vars.vehid = newSound
							end
						end

						vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
						sound = getVehSound(vars.vehid)

						if not sound then
							print("������ � ����� '@veh' (�"..i..") � user ������ '"..CFGuser.name.."'!")
							if vars.vehid then
								print("���������� � id '"..tostring(vars.vehid).."' �� ��� ������!")
							elseif vars.vehname then
								print("���������� � ��������� '"..tostring(vars.vehname).."' �� ��� ������!")
							end
							return false
						end

						if vars.vehname and vars.vehname == CFGuser.vehOnFoot then
							sound = DISPATCH_SOUNDS.suspect.onFoot
						elseif vars.id or vars.nick then
							-- ����� ���� �� ������, ���� ��� � ������.
							vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
							res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
							if res then
								for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
									table.insert(arrSounds, soundColor)
								end

								sound = getVehSound(vars.vehid)
							end
						end
					else
						print("������ � ����� '@area' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("���������� @vehname ��� @vehid ��� � ������!")
						return false
					end
				else
					if type(sound) ~= 'string' then
						print("������ � ����� '"..tostring(sound).."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
						print("�������� ���������� ������ ���� ������!")
						return false
					elseif sound:find("^DISP%.") then
						local s = sound:split('%.')
						local newSound
						if #s == 3 then
							if s[2] == 'codes' or s[2] == 'codesWithIn' then
								s[3] = tonumber(s[3])
							end
							newSound = DISPATCH_SOUNDS[s[2]][s[3]]
						else
							newSound = DISPATCH_SOUNDS[s[2]]
						end

						if not newSound then
							print("������ � ����� '"..sound.."' (�"..i..") � user ������ '"..CFGuser.name.."'!")
							print("���� �� ������! ��������� ��� �� ��� ����� ��������.")
							print("�������� ���� ����� � ������� � ���������� DISPATCH_SOUNDS � ����� config.lua.")
							print("������� �������� ����� ��������!")
							return false
						end
						sound = newSound
					else
						sound = PATH.audio..newSound
					end
				end

			else
				if varname == 'area' then
					sound = getAreaSoundPatch(vars.area)
					if not sound then
						print("������ � ����� �"..i.." � user ������ '"..CFGuser.name.."'!")
						print("@area �� �������.")
						return false
					end

				elseif varname == 'veh' then
					-- ������ �� ������� ���� �� ���������� ������
					-- � ���� ������
					if vars['vehname'] or vars['vehid'] then
						vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
						sound = getVehSound(vars.vehid)
						if not sound then
							print("������ � ����� '@veh' (�"..i..") � user ������ '"..CFGuser.name.."'!")
							if vars.vehid then
								print("���������� � id '"..tostring(vars.vehid).."' �� ��� ������!")
							elseif vars.vehname then
								print("���������� � ��������� '"..tostring(vars.vehname).."' �� ��� ������!")
							end
							return false
						end

						if CFGuser.veh and vars.vehname == CFGuser.vehOnFoot then
							sound = DISPATCH_SOUNDS.suspect.onFoot
						elseif vars.id or vars.nick then
							-- ����� ���� �� ������, ���� ��� � ������.
							vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
							res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)

							if res then
								for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
									table.insert(arrSounds, soundColor)
								end
								sound = getVehSound(vars.vehid)
							end
						end
					else
						print("������ � ����� �"..i.." � user ������ '"..CFGuser.name.."'!")
						print("���������� �������� ���� ����������, ��� ��� ...")
						print("... � �������� �� ������� �� @vehname, �� @vehid!")
						return false
					end
				else
					sound = vars[varname]
				end
			end
		-- ������������� ����
		elseif sound:find("%.") then
			sound = sound:gsub("/", "\\")
			sound = PATH.audio..sound
		else
			print("����������� ���� "..sound.." (�"..i..") � user ������ '"..CFGuser.name.."'!")
			return false
		end

		arrSounds[#arrSounds+1] = sound
	end

	return arrSounds
end




-- PLAY SOUNDS --

function playDispatch(event, vars)
	local CFGev = CFG[event]

	if event == 'call' then
		lua_thread.create(playSounds, {
			DISPATCH_SOUNDS.words.weGot10,
			randomChoice(DISPATCH_SOUNDS.codesWithIn),
			getAreaSoundPatch(vars.area)
		}, 'callsVolume', true)

	elseif event == 'gangActivity' then
		-- ������� ��� ������ ���� Jefferson2.
		local msgs = {}
		for _, fname in ipairs(GANG_ACTIVITY_SOUNDS) do
			if fname:find(vars.area, 1, true) then
				msgs[#msgs+1] = fname
			end
		end

		lua_thread.create(playSounds, randomChoice(msgs), 'callsVolume')

	elseif event == 'areaAndCode' then
		lua_thread.create(playSounds, PATH.audio..PATH.areaAndCode..vars.area..'.wav', 'callsVolume')

	elseif event == 'find' then
		lua_thread.create(playSounds, {
			DISPATCH_SOUNDS.suspect.lastSeen,
			DISPATCH_SOUNDS.words.inA,
			getAreaSoundPatch(vars.area),
			(
				vars['vehid'] and DISPATCH_SOUNDS.words.onA or
				vars['onFoot'] and DISPATCH_SOUNDS.suspect.onFoot or
				nil
			),
			unpack(getCarColorSound(vars.vehcolor)),
			getVehSound(vars.vehid)
		}, 'findVolume', true)

	elseif event == 'code1' then
		lua_thread.create(playSounds, randomChoice(CODE_1_SOUNDS), 'radioVolume')

	elseif event == 'code0' then
		lua_thread.create(playSounds, randomChoice(CODE_0_SOUNDS), 'radioVolume')
	end
end

function playSounds(array, volume, isPlayRadioOn)
	-- ������ � lua_thread
	array = toTable(array)

	while DISP_IS_SPEAK do wait(0) if IS_CLEAN_QUEUE then return end end
	DISP_IS_SPEAK = true

	local radioOnSound
	if isPlayRadioOn then
		radioOnSound = loadAudioStream(DISPATCH_SOUNDS.radioOn)
		play(radioOnSound, volume)
		wait(350)
	end

	for _, sound in pairs(array) do
		if type(sound) == 'string' then
			sound = loadAudioStream(sound)
		end
		if sound then
			wait(play(sound, volume))
		end
	end

	if isPlayRadioOn then
		wait(300)
		play(radioOnSound, volume)
	end
	wait(800)

	DISP_IS_SPEAK = false
end

function play(sound, volume)
	--[[������� ����������� ���� sound � ���������� volume
	���� �������� ������, �� �� ����� ��������� �� ��� �����
	� ���������� ������ ������� ����� � �������������, 
	���������� ��� ������� wait(), 
	����� ��������� ���� � ���� ���������� ����� �����.
	����������: wait(play(loadAudioStream('find.mp3'), 'find'))]]

	if tonumber(volume) then
		volume = tonumber(volume)
	elseif type(volume) == 'string' then
		volume = INI.INI[volume]
	else
		volume = 1
	end

	setAudioStreamVolume(sound, volume)
	setAudioStreamState(sound, 1)
	return getAudioStreamLength(sound) * 1000 - 35
end




-- OTHER GETTERS --

function getModelIdAndColorByPlayerId(id)
	local playerInStream, playerHandle

	local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)

	if id ~= playerId then
		playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(id)
	else
		playerInStream, playerHandle = true, PLAYER_PED
	end

	if playerInStream and isCharInAnyCar(playerHandle) then
		local carHandle = storeCarCharIsInNoSave(playerHandle)
		local vehId = getCarModel(carHandle)
		local vehColor
		if CARS_WITH_DEF_COLOR[vehId] then
			vehColor = CARS_WITH_DEF_COLOR[vehId]
		elseif getCurrentVehiclePaintjob(carHandle) ~= -1 then
			vehColor = "Customize"
		elseif inArray(vehId, CARS_TO_SOUND_TWO_COLORS) then
			local c1, c2 = getCarColours(carHandle)
			vehColor = {c1, c2}
		else
			vehColor, _ = getCarColours(carHandle)
		end

		return true, vehId, vehColor
	else
		return false
	end
end

function getMarkerArea(markerId)
	local markerPos
	for _, icon in ipairs(MAP_ICONS) do
		if icon.type == markerId then
			markerPos = icon.pos
			break
		end
	end
	if not markerPos then
		print("�� ������� ������� ������� � id "..markerId..'!')
		return false 
	end

	return calculateArea(markerPos.x, markerPos.y)
end

function calculateArea(x, y)
	for i, v in ipairs(AREAS) do
		if (x >= v[2]) and (y >= v[3]) and (x <= v[5]) and (y <= v[6]) then
			return v[1]
		end
	end
	return "Unknown"
end

function getPlayerCity(ped)
	if getCharActiveInterior(ped) ~= 0 then return "San Andreas" end

	local x, y, _ = getCharCoordinates(ped)
	local reversedAreasArray = cloneTable(AREAS)
	table.reverse(reversedAreasArray)

	for i, v in ipairs(reversedAreasArray) do
		if (x >= v[2]) and (y >= v[3]) and (x <= v[5]) and (y <= v[6]) then
			return v[1]
		end
	end

	return nil
end

function getPlayerArea(ped)
	if getCharActiveInterior(ped) ~= 0 then return "San Andreas" end
	local x, y, _ = getCharCoordinates(ped)
	return calculateArea(x, y)
end




-- GETTERS SOUNDS --

function getCarModelByName(nameModel)
	for id, name in pairs(CAR_NAMES) do
		if name:tolower() == nameModel:tolower() then
			return id
		end
	end
	-- ����������������
	if CFG.serverConfig then
		for name, id in pairs(CFG.serverConfig.vehNames) do
			if name:tolower() == nameModel:tolower() then
				return id
			end
		end
	end
end

function getVehSound(modelCarId)
	for class, arrayIds in pairs(CARS) do
		for _, idModel in ipairs(arrayIds) do
			if idModel == modelCarId then
				return loadAudioStream(PATH.audio..PATH.vehicles..class..'.wav')
			end
		end
	end
end

function getCarColorSound(color)
	-- ���������� ������
	if type(color) == 'string' then
		return {loadAudioStream(PATH.audio..PATH.colors..color..'.wav')}
	end

	color = toTable(color)
	local sounds = {}
	local firstColor

	-- ���� ������� ����
	for _, c in ipairs(color) do
		if c ~= "Not sound" then

			for colorName, colorsArray in pairs(COLORS) do
				for _, idColor in ipairs(colorsArray) do
					if c == idColor then
						local t = colorName:split(" ")
						if t[#t] ~= firstColor then
							-- ���� light/dark
							if #t == 2 then
								sounds[#sounds+1] = loadAudioStream(
									PATH.audio..PATH.colors..t[1]..'.wav'
								)
							end
							sounds[#sounds+1] = loadAudioStream(
								PATH.audio..PATH.colors..t[#t]..'.wav'
							)
							firstColor = t[#t]
						end
					end

				end
			end

		end
	end

	return sounds
end

function getAreaSoundPatch(area)
	area = area:gsub('-', ' '):gsub('_', ' '):gsub("'", ''):gsub('"', '')

	local patch = PATH.audio..PATH.area..area..'.wav'
	if doesFileExist(patch) then
		return patch
	else
		local newArea = AREAS_NOT_VOICED[area:tolower()]

		-- ����������������
		if not newArea and CFG.serverConfig and CFG.serverConfig.areas then
			for name, ar in pairs(CFG.serverConfig.areas) do
				if name:tolower() == area:tolower() then
					newArea = ar
				end
			end
		end

		if newArea then
			return getAreaSoundPatch(newArea)
		else
			print("������ \""..area.."\" �� �������.")
			return false
		end
	end
end




-- ICONS ON MAP --

-- ������ �� ����� (id: �����������)
function sampev.onSetMapIcon(id, pos, typeIcon, color, style)
	-- print("onSetMapIcon id="..id..", type="..typeIcon..", ("..pos.x..", "..pos.y..")")
	MAP_ICONS[#MAP_ICONS+1] = {
		id=id, 
		pos=pos, 
		type=typeIcon
	}
end

function sampev.onRemoveMapIcon(id)
	-- print("onRemoveMapIcon id="..id)
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == id then
			MAP_ICONS[i] = nil
		end
	end
end


-- ������� ����� (id: 1)
function sampev.onSetCheckpoint(pos, radius)
	-- print("onSetCheckpoint ("..pos.x..", "..pos.y..")")
	-- ������� ���������� �����
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == 'check' then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id='check',
		pos=pos,
		type=1
	}
end

function sampev.onDisableCheckpoint()
	-- print("onDisableCheckpoint")
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == 'check' then
			MAP_ICONS[i] = nil
		end
	end
end

-- �������� �������� (id: 2)
function sampev.onSetRaceCheckpoint(type, pos, nextPos, size)
	-- print("onSetRaceCheckpoint ("..pos.x..", "..pos.y..")")
	-- ������� ���������� �����
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == 'race' then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id='race',
		pos=pos,
		type=2
	}
end

function sampev.onDisableRaceCheckpoint()
	-- print("onDisableRaceCheckpoint")
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == 'race' then
			MAP_ICONS[i] = nil
		end
	end
end




-- HELP FUNCTIONS --

function inArray(variable, arr, isRegEx)
	for i, element in pairs(arr) do
		if type(i) == 'string' then
			element = i
		end
		if type(variable) == 'string' and string.find(variable:tolower(), element:tolower(), 1, not isRegEx) then
			return true
		elseif variable == element then
			return true
		end
	end
	return false
end

function varInElementsArray(var, arr)
	for _, el in pairs(arr) do
		if string.find(el:tolower(), var:tolower(), 1, true) then
			return true
		end
	end
	return false
end

function esc(s)
      return (s:gsub('%^', '%%^')
               :gsub('%$', '%%$')
               :gsub('%(', '%%(')
               :gsub('%)', '%%)')
               :gsub('%.', '%%.')
               :gsub('%[', '%%[')
               :gsub('%]', '%%]')
               :gsub('%*', '%%*')
               :gsub('%+', '%%+')
               :gsub('%-', '%%-')
               :gsub('%?', '%%?'))
end

function randomChoice(arr)
	-- ���������� ��������� ������� arr
	if #arr == 0 then
		local iter = 0
		newArr = {}
		for i, it in pairs(arr) do
			iter = iter + 1
			newArr[iter] = it
		end
		arr = newArr
	end
	math.randomseed(os.time())
	return arr[math.random(#arr)]
end

function string:split(sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(self, "([^"..sep.."]+)") do
		t[#t+1] = str
	end
	return t
end

function concatTablesWithKeys(t1, t2)
	for k,v in pairs(t2) do
		t1[k] = v
	end

	return t1
end

function toTable(var)
	if type(var) ~= 'table' then
		return {var}
	else
		return var
	end
end

function cloneTable(t)
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = cloneTable(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

function table.reverse(t)
	for i = 1, math.floor(#t/2) do
		v = t[i]
		t[i] = t[#t-i+1]
		t[#t-i+1] = v
	end
end

function sampGetPlayerIdByNickname(nick)
    local _, myid = sampGetPlayerIdByCharHandle(playerPed)
    if tostring(nick) == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1000 do if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == tostring(nick) then return i end end
end




-- OTHER FUNCTIONS --

function checkUpdates()
	if not INI.INI.isCheckUpdates then return end

	local fpath = os.tmpname()
	downloadUrlToFile(
		"https://raw.githubusercontent.com/don-aks/PoliceDispatchLua/main/Police%20Dispatch.lua", 
		fpath,
		function(_, status, _, _)
			if status == download_status.STATUS_ENDDOWNLOADDATA then
				if doesFileExist(fpath) then
					local f = io.open(fpath, "r")
					local f_text = f:read("*a")
					f:close()
					local versNum = string.match(f_text, "script_version_number%s*%((%d+)%)")

					if versNum and tonumber(versNum) > thisScript().version_num then
						local versStr = string.match(f_text, "script_version%s*%([\"'](.-)[\"']%)")
						chatMessage("��������! �������� ���������� {32B4FF}v"..versStr..'{ffffff}.')
						chatMessage("��� �������� �� �������� ������� ����������� ���� {32B4FF}/pdradio{ffffff}.")
					end
				end
			end
		end
	)
end

function mainMenu()
	local text = string.format(
		"������:\t%s\n".. -- 0
		"�������� ����������\t%s\n".. -- 1
		"�������������� � ���\t%s\n".. -- 2
		"��������� {FF4400}������� 911:\t{FFFFFF}%s\n".. -- 3
		"��������� {ABCDEF}/find:\t{FFFFFF}%s\n".. -- 4
		"��������� {8D8DFF}/r:\t{FFFFFF}%s\n".. -- 5
		"��������� {66DDAA}user-�������:\t{FFFFFF}%s\n".. -- 6
		"  \n".. -- 7
		"���������� {66DDAA}user-�������\n".. -- 8
		"�������� ��������\n".. -- 9
		"�������� ������� ���������������\n".. -- 10
		"  \n".. -- 11
		"�������� �������", -- 12

		(INI.INI.state and "{21C90E}���." or '{C91A14}����.'),
		(INI.INI.isCheckUpdates and "{21C90E}���." or '{C91A14}����.'),
		(INI.INI.soundInAFK and "{21C90E}���." or '{C91A14}����.'),
		(INI.INI.callsVolume == 0 and "{C91A14}����." or INI.INI.callsVolume), 
		(INI.INI.findVolume == 0 and "{C91A14}����." or INI.INI.findVolume),
		(INI.INI.radioVolume == 0 and "{C91A14}����." or INI.INI.radioVolume),
		(INI.INI.userVolume == 0 and "{C91A14}����." or INI.INI.userVolume)
	)
	sampShowDialog(20000, "��������� - PD Radio v"..thisScript().version.." | "..CFG.name, text, BTN1, BTN2, 4)
end

function checkDialogsRespond()
	-- ��������� � main() while true do
	local result, button, list, _ = sampHasDialogRespond(20000)
	if result and button == 1 then
		listMainMenu = list
		if list == 0 then
			INI.INI.state = not INI.INI.state
			saveIni()
			mainMenu()
		elseif list == 1 then
			INI.INI.isCheckUpdates = not INI.INI.isCheckUpdates
			saveIni()
			mainMenu()
		elseif list == 2 then
			INI.INI.soundInAFK = not INI.INI.soundInAFK
			saveIni()
			mainMenu()
			if not INI.INI.soundInAFK then
				chatMessage("������ ��������� �� ����� ���������� �������, ������� ���������, ����� �� ���� � ��� ������ 2� �����.")
			end
		elseif list == 3 then
			sampShowDialog(20001, "��������� {FF4400}������� 911:", "���� �� ������ ��������� �������, ������� 0.", 
				BTN1, BTN2, 1)
		elseif list == 4 then
			sampShowDialog(20001, "��������� {ABCDEF}/find:", "���� �� ������ ��������� �������, ������� 0.", 
				BTN1, BTN2, 1)
		elseif list == 5 then
			sampShowDialog(20001, "��������� {8D8DFF}/r:", "���� �� ������ ��������� �������, ������� 0.", 
				BTN1, BTN2, 1)
		elseif list == 6 then
			sampShowDialog(20001, "��������� {66DDAA}user-�������:", "���� �� ������ ��������� �������, ������� 0.", 
				BTN1, BTN2, 1)
		elseif list == 7 then
			mainMenu()
		elseif list == 8 then
			local userEvents = ""
			if INI[CFG.name.."_UserEvents"] then
				for i, it in ipairs(INI[CFG.name.."_UserEvents"]) do
					userEvents = userEvents .. CFG.user[i].name.."\t"..(it and "{21C90E}���." or "{C91A14}����.").."\n"
				end
			end
			if userEvents == "" then
				chatMessage("User-������� �� �������!")
				mainMenu()
			else
				sampShowDialog(20002, "���������� user-�������", userEvents,
					BTN1, BTN2, 4)
			end
		elseif list == 9 then
			sampShowDialog(20003, "�������� ��������", 
				"������� ������ ������ �� ���� ��� �������� � ���������������:\n"..
				"��� ������� ����� ������ ����������� ������� R: (���� ��� #) (������).",
			BTN1, BTN2, 1)
		elseif list == 10 then
			IS_CLEAN_QUEUE = true
			wait(100)
			IS_CLEAN_QUEUE = false
			chatMessage("������� ��������������� ���� �������.")
		elseif list == 11 then
			mainMenu()
		elseif list == 12 then
			os.execute("start https://github.com/don-aks/PoliceDispatchLua/releases")
		end
	end

	-- ���������
	local result, button, _, input = sampHasDialogRespond(20001)
	if result and button == 1 then
		if not tonumber(input) or tonumber(input) < 0 then
			chatMessage("��������� ������ ���� ������ ������� ��� ������ ����.")
		else
			input = tonumber(input)
			if listMainMenu == 2 then INI.INI.callsVolume = input
			elseif listMainMenu == 3 then INI.INI.findVolume = input
			elseif listMainMenu == 4 then INI.INI.radioVolume = input
			elseif listMainMenu == 5 then INI.INI.userVolume = input end
			saveIni()
		end
		mainMenu()
	elseif result then
		mainMenu()
	end

	-- ���������� user �������
	local result, button, list, _ = sampHasDialogRespond(20002)
	if result and button == 1 then
		local key = CFG.name.."_UserEvents"
		INI[key][list+1] = not INI[key][list+1]
		saveIni()

		local userEvents = ""
		for i, it in ipairs(INI[CFG.name.."_UserEvents"]) do
			userEvents = userEvents .. CFG.user[i].name.."\t"..(it and "{21C90E}���." or "{C91A14}����.").."\n"
		end
		sampShowDialog(20002, "���������� user-�������", userEvents,
			BTN1, BTN2, 4)
	elseif result then
		mainMenu()
	end

	-- �������� ������
	local result, button, _, input = sampHasDialogRespond(20003)
	if result and button == 1 then
		local color = input:match("^R: (%w+) ")
		input = input:gsub("^R: (%w+) ", "")

		if color and not tonumber(color) then
			color = tonumber("0x"..color)
		end

		local h, s = handleEvent(input, color)
		if h == false and s == 'not ev' then
			chatMessage("������� �� �������. �������� �� ����������� ����� ������ � config.json ��� � ���� ��� �����.")
			chatMessage("����, ���� ��� user-�����, �� ����� ���� �������� � ����������.")
		elseif h == false and s == 'volume' then
			chatMessage("�������, ������� �� ��������� �������������, ���������.")
		elseif h == false and s == 'question words' then
			chatMessage("� ��������� �� ����� ������� �������������� �����.")
		elseif h == false and s == 'text radio' then
			chatMessage("� ��������� �� ����� �� ������� ������� �������� ����.")
		elseif h == false and s == 'stopWords' then
			chatMessage('� ������ ������� "����-�����" �� config.json.')
		elseif h == false then
			chatMessage("��� �������� ������ ��������� ������. ��������� � moonloader.log.")
		elseif h == true then
			chatMessage("���� ������ ��������� ���� ������, ������� ��������� �� ���������� �������.")
			chatMessage("����������: ��� ������ ������ ����� ������ � ����, ������ ����������.")
		else
			chatMessage("�������, ��� ������ �������.")
		end
	elseif result then
		mainMenu()
	end
end


function saveIni()
	inicfg.save(INI, PATH.ini)
end

-- ������� �� ��������� youtube.com/c/Brothersincompany <3
-- vk.com/donaks