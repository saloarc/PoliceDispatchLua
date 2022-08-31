script_name("Police Dispath")
script_author("hobby")
script_url("github.com/don-aks/PoliceDispatchLua/")
script_version("2.1.3-gambit-fix")
script_version_number(8)
script_properties("work-in-pause")

require "lib.moonloader"
local download_status = require("lib.moonloader").download_status
local inicfg = require "inicfg"
local memory = require "memory"
local json = require ("dkjson")
local encoding = require "encoding"
local thanks = ""

encoding.default = "CP1251"
local u8 = encoding.UTF8
package.path = package.path..";"..getWorkingDirectory().."\\?.lua"

require "config.PoliceDispatch.config"

local DISP_IS_SPEAK = false
local VARS_AND_VALUES = {}
local MAP_ICONS = {}
local CFG, INI, CFG_FILE_NAME

local TIME_ENTER_AFK
local IS_CLEAN_QUEUE = false


function chatMessage(text)
	return sampAddChatMessage(u8:decode("[Police Dispath]: {ffffff}"..text), 0xFF3523)
end

function mainMenu()
	local btn1 = u8:decode("Выбрать")
	local btn2 = u8:decode("Отмена")
	
	local text = string.format(
		"Скрипт:\t%s\n".. -- 0
		"Проверка обновлений\t%s\n".. -- 1
		"Воспроизводить в АФК\t%s\n".. -- 2
		"Громкость {FF4400}вызовов 911:\t{FFFFFF}%s\n".. -- 3
		"Громкость {ABCDEF}/find:\t{FFFFFF}%s\n".. -- 4
		"Громкость {8D8DFF}/r:\t{FFFFFF}%s\n".. -- 5
		"Громкость {66DDAA}user-эвентов:\t{FFFFFF}%s\n".. -- 6
		"  \n".. -- 7
		"Отключение {66DDAA}user-эвентов\n".. -- 8
		"Проверка паттерна\n".. -- 9
		"Очистить очередь воспроизведения\n".. -- 10
		"  \n".. -- 11
		"Страница скрипта\n".. -- 12
		"Связь с автором {8D8DFF}(VK)", -- 13

		(INI.INI.state and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.isCheckUpdates and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.soundInAFK and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.callsVolume == 0 and "{C91A14}Откл." or INI.INI.callsVolume), 
		(INI.INI.findVolume == 0 and "{C91A14}Откл." or INI.INI.findVolume),
		(INI.INI.radioVolume == 0 and "{C91A14}Откл." or INI.INI.radioVolume),
		(INI.INI.userVolume == 0 and "{C91A14}Откл." or INI.INI.userVolume)
	)
	title = u8:decode("Настройки - Police Dispath v"..thisScript().version.." | "..CFG.configInfo.name or CFG_FILE_NAME)
	sampShowDialog(20000, title, u8:decode(text), btn1, btn2, 4)
end

function saveIni()
	inicfg.save(INI, PATH.config.."config.ini")
end

local v = getMoonloaderVersion()
if v < 26 then
	chatMessage("Ваша версия moonloader не поддерживается. Установите 026-beta или выше.")
	chatMessage("Ссылка на скачивание более новой версии: https://www.blast.hk/threads/13305/")
	thisScript():unload()
	return
end

local res, sampev = pcall(require, "lib.samp.events")
if not res then
	chatMessage("Установите SAMP.LUA! {32B4FF}blast.hk/threads/59503{FFFFFF}.")
	thisScript():unload()
	return
end

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	while sampGetCurrentServerName() == "SA-MP" do wait(100) end

	local currentServerName = sampGetCurrentServerName()
	local ip, port = sampGetCurrentServerAddress()
	local currentServerIP = ip..":"..port
	local filesHandle, configFileName = findFirstFile(PATH.config.."servers/*.json")
	for _ = 1, 100000 do
		configFile = io.open(PATH.config.."servers/"..configFileName, "r")
		local config = json.decode(configFile:read("*a"))

		if isValueIsInArray(currentServerIP, toTable(config.serverInfo.ip)) or currentServerName:find(config.serverInfo.name, 1, true) then
			CFG = config
			break
		end
		configFileName = findNextFile(filesHandle)
		if not configFileName then break end
	end
	CFG_FILE_NAME = configFileName

	INI = inicfg.load({
		INI={
			state=true,
			isCheckUpdates=true,
			soundInAFK=false,
			callsVolume=3,
			findVolume=3,
			radioVolume=3,
			userVolume=3,
			radioOnSound="radio_on.wav",
			radioOffSound="radio_on.wav"
		}
	}, PATH.config.."config.ini")

	local tUser = {}
	if CFG.events.user then
		for i, it in ipairs(CFG.events.user) do
			tUser[i] = true
		end
	end

	local keyServer = CFG.configInfo.name.."_UserEvents"
	if #tUser > 0 then
		if not INI[keyServer] or #tUser ~= #INI[keyServer] then
			INI[keyServer] = tUser
		end
	end

	saveIni()
	if INI.INI.isCheckUpdates then
		local fpath = "%TEMP%/Police Dispath.lua"
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
							chatMessage("Внимание! Доступно обновление {32B4FF}v"..versStr.."{ffffff}.")
							chatMessage("Для перехода на страницу скрипта используйте меню {32B4FF}/pdradio{ffffff}.")
						end
					end
				end
			end
		)
	end

	sampRegisterChatCommand("pdradio", mainMenu)

	if INI.INI.state then
		chatMessage("Загружен. Управление скриптом: {32B4FF}/pdradio{FFFFFF}. Автор: {32B4FF}hobby.{FFFFFF}.")
	else
		chatMessage("Отключен! Управление скриптом: {32B4FF}/pdradio{FFFFFF}. Автор: {32B4FF}hobby.{FFFFFF}.")
	end

	local radioVolume = memory.read(0xBA6798, 1)
	if INI.INI.state and radioVolume == 0 then
		chatMessage("Внимание! Включите радио в настройках для того, чтобы скрипт заработал и перезайдите в игру, если звук не появится.")
	end

	while true do
		wait(20)
		if not INI.INI.soundInAFK then
			if not TIME_ENTER_AFK and isGamePaused() then
				TIME_ENTER_AFK = os.clock()
			elseif TIME_ENTER_AFK and not isGamePaused() then
				TIME_ENTER_AFK = nil
			end
		end

		local btn1 = u8:decode("Выбрать")
		local btn2 = u8:decode("Отмена")
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
					chatMessage("Теперь диспетчер не будет озвучивать события, которые произошли, когда вы были в АФК больше 2х минут.")
				end
			elseif list == 3 then
				sampShowDialog(20001, u8:decode("Громкость {FF4400}вызовов 911:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 4 then
				sampShowDialog(20001, u8:decode("Громкость {ABCDEF}/find:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 5 then
				sampShowDialog(20001, u8:decode("Громкость {8D8DFF}/r:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 6 then
				sampShowDialog(20001, u8:decode("Громкость {66DDAA}user-эвентов:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 7 then
				mainMenu()
			elseif list == 8 then
				local userEvents = ""
				if INI[CFG.configInfo.name.."_UserEvents"] then
					for i, it in ipairs(INI[CFG.configInfo.name.."_UserEvents"]) do
						userEvents = userEvents .. CFG.events.user[i].name.."\t"..(it and "{21C90E}Вкл." or "{C91A14}Откл.").."\n"
					end
				end
				if userEvents == "" then
					chatMessage("User-эвентов не найдено!")
					mainMenu()
				else
					sampShowDialog(20002, u8:decode("Отключение user-эвентов - Police Dispath v"..thisScript().version), u8:decode(userEvents),
						btn1, btn2, 4)
				end
			elseif list == 9 then
				text = "Введите нужную строку из чата для проверки и воспроизведения:\n"..
				"Для задания цвета строки используйте вначале R: (цвет без #) (Строка)."
				sampShowDialog(20003, u8:decode("Проверка паттерна - Police Dispath v"..thisScript().version), u8:decode(text), btn1, btn2, 1)
			elseif list == 10 then
				IS_CLEAN_QUEUE = true
				wait(100)
				IS_CLEAN_QUEUE = false
				chatMessage("Очередь воспроизведения была очищена.")
			elseif list == 11 then
				mainMenu()
			elseif list == 12 then
				os.execute("start https://github.com/don-aks/PoliceDispatchLua/releases")
			elseif list == 13 then
				os.execute("start https://vk.com/donaks")
			end
		end

		local result, button, _, input = sampHasDialogRespond(20001)
		if result and button == 1 then
			if not tonumber(input) or tonumber(input) < 0 then
				chatMessage("Громкость должно быть числом большим или равным нулю.")
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

		local result, button, list, _ = sampHasDialogRespond(20002)
		if result and button == 1 then
			local key = CFG.configInfo.name.."_UserEvents"
			INI[key][list+1] = not INI[key][list+1]
			saveIni()

			local userEvents = ""
			for i, it in ipairs(INI[CFG.configInfo.name.."_UserEvents"]) do
				userEvents = userEvents .. CFG.events.user[i].name.."\t"..(it and "{21C90E}Вкл." or "{C91A14}Откл.").."\n"
			end
			sampShowDialog(20002, u8:decode("Отключение user-эвентов"), u8:decode(userEvents), btn1, btn2, 4)
		elseif result then
			mainMenu()
		end

		local result, button, _, input = sampHasDialogRespond(20003)
		if result and button == 1 then
			input = input:gsub("^R: (%w+) ", "")
			local color = input:match("^R: (%w+) ")
			if color and not tonumber(color) then
				color = tonumber("0x"..color)
			end

			-- local h, s = handleEvent(input, color)
			sampAddChatMessage(input, (color or -1))
			if h == false and s == "that server message is not triggered event" then
				chatMessage("Событие не найдено. Возможно вы неправильно ввели строку в config.json или в поле для ввода.")
				chatMessage("Либо, если это user-эвент, он может быть отключен в настройках.")
			elseif h == false and s == "volume" then
				chatMessage("Событие, которое вы пытаетесь воспроизвести, отключено.")
			elseif h == false and s == "question words" then
				chatMessage("В сообщении по рации найдено вопросительное слово.")
			elseif h == false and s == "text radio" then
				chatMessage("В сообщении по рации не найдено никаких ключевых слов.")
			elseif h == false and s == "stopWords" then
				chatMessage("В вызове найдены \"стоп-слова\" из config.json.")
			elseif h == false then
				chatMessage("При проверки строки произошла ошибка. Подробнее в moonloader.log.")
			elseif h == true then
				chatMessage("Ваша строка содержала мало данных, поэтому сохранена до следующего события.")
				chatMessage("Примечание: как только придет новая строка в чате, данные обнуляться.")
			else
				chatMessage("Кажется, все прошло успешно.")
			end
		elseif result then
			mainMenu()
		end
	end
end

function sampev.onServerMessage(color, message)
	if not INI or not CFG or not INI.INI.state then return true end
	message = u8(message)

	if not INI.INI.soundInAFK and TIME_ENTER_AFK and os.clock() - TIME_ENTER_AFK >= 120 then
		return true
	end

	local eventType
	if not CFG.user or #CFG.user == 0 then
		return
	end

	for i, ev in ipairs(CFG.events.user) do
		if INI[CFG.name.."_UserEvents"][i] then
			local patterns = toTable(ev.chatMessage)
			local colors = toTable(ev.colorChatMessage)

			if #colors < 1 or (#colors == 1 and colors == color) or isValueIsInArray(tonumber(color), colors) then
				for _, patt in ipairs(patterns) do
					if not ev.useRegexInPattern then
						patt = "^"..(
							patt:gsub("%^", "%%^")
							:gsub("%$", "%%$")
							:gsub("%(", "%%(")
							:gsub("%)", "%%)")
							:gsub("%.", "%%.")
							:gsub("%[", "%%[")
							:gsub("%]", "%%]")
							:gsub("%*", "%%*")
							:gsub("%+", "%%+")
							:gsub("%-", "%%-")
							:gsub("%?", "%%?")
						)
					end

					if message:find(patt:gsub("@([%a_]+)", ".+")) then
						userPattern = patt
						idUserEvent = i
						break
					end
				end
			end
		end
	end


	if userPattern then
		eventType = "user"
	end

	local varsAndValues
	for id_event, ev_type in ipairs(CFG.events) do
		local patterns = toTable(CFG.events[evtype].chatMessage)
		local colors = CFG.events[evtype].colorChatMessage
		
		if #colors < 1 or (#colors == 1 and colors == color) or isValueIsInArray(tonumber(color), colors) then
			for _, patt in ipairs(patterns) do
				if not CFG[evtype].useRegexInPattern then
					patt = "^"..(
						patt:gsub("%^", "%%^")
						:gsub("%$", "%%$")
						:gsub("%(", "%%(")
						:gsub("%)", "%%)")
						:gsub("%.", "%%.")
						:gsub("%[", "%%[")
						:gsub("%]", "%%]")
						:gsub("%*", "%%*")
						:gsub("%+", "%%+")
						:gsub("%-", "%%-")
						:gsub("%?", "%%?")
					)
				end
				
				if str:find(patt:gsub("@([%a_]+)", ".+")) then
					eventType = evtype
					varsAndValues = {}
					local vars = {}

					local start = 1
					local var
					for _ = 1, #message do
						_, start, var = patt:find("@([%a_]+)", start)
						if var then
							table.insert(vars, var)
						else
							break
						end
					end

					for _, var in ipairs(vars) do
						local patternFindVar = "(.+)"
						if var == "n" or var == "id" then
							patternFindVar = "(%%d+)"
						end

						local patternWithoutVar = patt:gsub(
							"@"..var.."[^%a_]",
							patternFindVar..(patt:match("@"..var.."([^%a_])") or "")
						):gsub("@([%a_]+)", ".+")

						varsAndValues[var] = message:match(patternWithoutVar)

						if not varsAndValues[var] then
							print("Warning: Не найдена переменная @"..var.." в строке \""..message.."\"!")
						end
					end
					
					break
				end
			end
		end
	end

	local markerId = CFG[eventType].markerId
	
	if not eventType then
		if #VARS_AND_VALUES > 0 then
			VARS_AND_VALUES = {}
		end
		return false, "that server message is not triggered event"
	end

	if VARS[eventType] then
		for k,v in pairs(VARS[event]) do
			varsAndValues[k] = v
		end
		VARS[eventType] = {}
	end

	if eventType == "find" then
		if INI.INI.findVolume == 0 then return false, "volume" end
		if not vars.area then
			if markerId then
				vars.area = getMarkerArea(markerId)
				if not vars.area then
					print("Иконка на карте с id "..markerId.." в эвенте find не найдена.")
					return false
				end
			elseif type(CFG.find.pattern) == "table" and #CFG.find.pattern > 1 then
				VARS["find"] = vars
				return true
			else
				print("Ошибка! Перменная @area не указана в эвенте find!")
				print("Укажите markerId или @area в сообщении и перезагрузите скрипт!")
				return false
			end
		end

		vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)

		if CFG.find.vehOnFoot and vars.vehname == CFG.find.vehOnFoot then
			vars.onFoot = true
		elseif vars.nick or vars.id then
			local playerId = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
			local playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(playerId)

			if playerInStream and isCharInAnyCar(playerHandle) then
				local carHandle = storeCarCharIsInNoSave(playerHandle)
				vars.vehid = getCarModel(carHandle)
				vars.vehcolor, _ = getCarColours(carHandle)
			end
		end

	elseif eventType == "call" then
		if INI.INI.callsVolume == 0 then return false, "volume" end
		if not vars.area or not vars.text then
			if type(CFG.call.pattern) == "table" and #CFG.call.pattern > 1 then
				VARS["call"] = vars
				return true
			else
				print("Ошибка! Переменная @area или @text не указана в эвенте call!")
				return false
			end
		end

		if isValueIsInArray(vars.text, CFG.config.stopWords) then
			return false, "stopWords"
		end

		if 		CFG.call.isPlayGangActivity and
				isValueIsInArray(str, CFG.config.dictionaryGangActivity) and
				varInElementsArray(vars.area, GANG_ACTIVITY_SOUNDS)
		then
			eventType = "gangActivity"
		elseif 	math.random(2) == 2 and
				varInElementsArray(vars.area, AREA_AND_CODE_SOUNDS) 
		then
			math.randomseed(os.time())
			eventType = "areaAndCode"
		end

	elseif eventType == "radio" then
		if INI.INI.radioVolume == 0 then return false, "volume" end
		if CFG.radio.isPlayShotsFired then
			if isValueIsInArray(vars.text, CFG.config.code0Words) then
				eventType = "code0"
			elseif isValueIsInArray(vars.text, CFG.config.code1Words) then
				eventType = "code1"
			end
		end

		if 	eventType == "radio" and
			type(CFG.radio.userMessages) == "table" and
			#CFG.radio.userMessages > 0
		then
			for _, usermsg in ipairs(CFG.radio.userMessages) do
				if isValueIsInArray(vars.text, toTable(usermsg.textFind), usermsg.useRegexInPattern) then
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
								-- В принципе рандомный район
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
							sounds[i] = PATH.audio..sound:gsub("/", "\\")
						end
					end

					lua_thread.create(
						playSounds,
						sounds,
						"radioVolume",
						usermsg.isPlayRadioOn
					)
					return
				end
			end
			return false, "that server message is not triggered event"
		elseif isValueIsInArray(vars.text, QUESTION_WORDS) then
			return false, "question words"
		elseif ev == "radio" then
			return false, "text radio"
		end

	elseif eventType == "user" then
		if INI.INI.userVolume == 0 then return false, "volume" end
		local arrSounds = {}
		
		local CFGuser = CFG.user[idUserEvent]
		CFGuser.sounds = toTable(CFGuser.sounds)
		for i, sound in ipairs(CFGuser.sounds) do
	
			if type(sound) ~= "string" then
				print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
				print("Пользовательские звуки должны быть между кавычками!")
				return false
	
			elseif sound:find("^DISP%.") then
				local s = sound:split("%.")
				if #s == 2 or #s == 3 then
					local newSound
					if #s == 3 then
						if s[2] == "codes" or s[2] == "codesWithIn" then
							s[3] = tonumber(s[3])
						end
						newSound = DISPATCH_SOUNDS[s[2]][s[3]]
					else
						newSound = DISPATCH_SOUNDS[s[2]]
					end
	
					if not newSound then
						print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
						print("Звук не найден! Убедитесь что вы все верно написали.")
						print("Сравните свои ключи с ключами в переменной DISPATCH_SOUNDS в файле config.lua.")
						print("Регистр символов имеет значение!")
						return false
					end
					sound = newSound
				else
					print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
					print("Указывать звук нужно: DISP.key1.key2. Пример: DISP.words.headTo10.")
					return false
				end
	
			elseif sound:find("^@") then
				local varname = sound:match("@([%a_]+)")
				if not varname then
					print("Некорректная переменная в звуке "..tostring(sound).." (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
					print("Переменные пишутся только латиницей или нижним подчеркиванием!")
					return false
				end
	
				if 	(not vars[varname]) and 
					(not (CFGuser.vars and CFGuser.vars[varname])) and
					(varname ~= "veh" or not (vars.vehname or vars.vehid))
				then
					if varname == "area" and CFGuser.markerId then
						local markerId = CFGuser.markerId
						local area = getMarkerArea(markerId)
						if not area then
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..(CFGuser.name).."\"!")
							print("Иконка на карте с id "..markerId.." в эвенте user не найдена.")
							return false
						end
	
						local newSound = getAreaSoundPatch(area)
						if not newSound then
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("@area не найдено.")
							return false
						end
						sound = newSound
	
					elseif varname == "veh" then
						if vars.id or vars.nick then
							vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
							res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
							if res then
								for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
									table.insert(arrSounds, soundColor)
								end
								sound = getVehSound(vars.vehid)
							else
								print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								print("Переменной @vehname или @vehid нет в строке!")
								print("И игрок, указанный в переменных @id или @nick вне зоне стрима!")
								return false
							end
						else
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					elseif varname == "suspectveh" then
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
								local playerInStream, playerHandle
	
								local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
								if id ~= playerId then
									playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(vars.id)
								else
									playerInStream, playerHandle = true, PLAYER_PED
								end
	
								if not playerInStream then
									print("Warning @suspectveh: Игрок вне зоне стрима в user эвенте \""..CFGuser.name.."\"!")
									sound = nil
								else
									table.insert(arrSounds, DISPATCH_SOUNDS.suspect.suspect1)
									sound = DISPATCH_SOUNDS.suspect.onFoot
								end
							end
						else
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					elseif varname == "cityplayer" then
						local city = getPlayerCity(PLAYER_PED)
						if not city then
							local x, y, z = getCharCoordinates(PLAYER_PED)
							print("Ошибка! Не удалось определить город игрока.")
							print("Координаты: x = "..x..", y = "..y..", z = "..z)
							return false
						end
						sound = getAreaSoundPatch(city)
					elseif varname == "areaplayer" then
						local area = getPlayerArea(PLAYER_PED)
						if not area then
							local x, y, z = getCharCoordinates(PLAYER_PED)
							print("Ошибка! Не удалось определить район игрока.")
							print("Координаты: x = "..x..", y = "..y..", z = "..z)
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
							sound = getAreaSoundPatch(randomChoice(AREAS)[1])
						else
							sound = getAreaSoundPatch(
								randomChoice(LIST_AREAS_IN_REGIONS[city])
							)
						end
					elseif varname == "codezero" then
						sound = randomChoice(CODE_0_SOUNDS)
					elseif varname == "codeone" then
						sound = randomChoice(CODE_1_SOUNDS)
					elseif varname == "megaphone" then
						if coords == "player" then
							handleOrId = getPlayerHandleOrIdByVariables(vars)
							setPlay3dAudioStreamAtChar(sound, handleOrId)
						end
						setAudioStreamVolume(sound, 5)
						setAudioStreamState(sound, 1)
					else
						print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
						print("Переменной @"..varname.." нет в строке!")
						return false
					end
	
				elseif
					CFGuser.vars and 
					(
						(CFGuser.vars[varname]) or (
							varname == "veh" and
							(CFGuser.vars["vehname"] or CFGuser.vars["vehid"])
						)
					)
				then
					if varname ~= "veh" then
						newSound = CFGuser.vars[varname] [vars[varname]]
						if newSound then
							sound = newSound
						else
							print("Warning! В vars."..varname.." нет значения "..vars[varname]..". "..
								"Переменная не перезаписалась.")
						end
					end

					if varname == "area" then
						local area = sound
						sound = getAreaSoundPatch(area)
						if not sound then
							print("Ошибка в звуке \"@area\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("После замены на пользовательскую конструкцию, район "..area.." не был найден.")
							return false
						end
					elseif varname == "veh" then
						if vars["vehname"] or vars["vehid"] then
							if CFGuser.vars["vehname"] then
								local newSound = CFGuser.vars.vehname[vars.vehname]
								if newSound then
									vars.vehname = newSound
								end
							end
							if CFGuser.vars["vehid"] then
								local newSound = CFGuser.vars.vehid[vars.vehid]
								if newSound then
									vars.vehid = newSound
								end
							end
	
							vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
							sound = getVehSound(vars.vehid)
	
							if not sound then
								print("Ошибка в звуке \"@veh\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								if vars.vehid then
									print("Автомобиль с id \""..tostring(vars.vehid).."\" не был найден!")
								elseif vars.vehname then
									print("Автомобиль с названием \""..tostring(vars.vehname).."\" не был найден!")
								end
								return false
							end
	
							if vars.vehname and vars.vehname == CFGuser.vehOnFoot then
								sound = DISPATCH_SOUNDS.suspect.onFoot
							elseif vars.id or vars.nick then
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
							print("Ошибка в звуке \"@area\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					else
						if type(sound) ~= "string" then
							print("Ошибка в звуке \""..tostring(sound).."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Значение переменной должна быть строка!")
							return false
						elseif sound:find("^DISP%.") then
							local s = sound:split("%.")
							local newSound
							if #s == 3 then
								if s[2] == "codes" or s[2] == "codesWithIn" then
									s[3] = tonumber(s[3])
								end
								newSound = DISPATCH_SOUNDS[s[2]][s[3]]
							else
								newSound = DISPATCH_SOUNDS[s[2]]
							end
	
							if not newSound then
								print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								print("Звук не найден! Убедитесь что вы все верно написали.")
								print("Сравните свои ключи с ключами в переменной DISPATCH_SOUNDS в файле config.lua.")
								print("Регистр символов имеет значение!")
								return false
							end
							sound = newSound
						else
							sound = PATH.audio..newSound
						end
					end
	
				else
					if varname == "area" then
						sound = getAreaSoundPatch(vars.area)
						if not sound then
							print("Ошибка в звуке №"..i.." в user эвенте \""..CFGuser.name.."\"!")
							print("@area не найдено.")
							return false
						end
	
					elseif varname == "veh" then
						if vars["vehname"] or vars["vehid"] then
							vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
							sound = getVehSound(vars.vehid)
							if not sound then
								print("Ошибка в звуке \"@veh\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								if vars.vehid then
									print("Автомобиль с id \""..tostring(vars.vehid).."\" не был найден!")
								elseif vars.vehname then
									print("Автомобиль с названием \""..tostring(vars.vehname).."\" не был найден!")
								end
								return false
							end
	
							if CFGuser.veh and vars.vehname == CFGuser.vehOnFoot then
								sound = DISPATCH_SOUNDS.suspect.onFoot
							elseif vars.id or vars.nick then
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
							print("Ошибка в звуке №"..i.." в user эвенте \""..CFGuser.name.."\"!")
							print("Невозможно получить звук автомобиля, так как ...")
							print("... в паттерне не указана ни @vehname, ни @vehid!")
							return false
						end
					else
						sound = vars[varname]
					end
				end
			elseif sound:find("%.") then
				sound = sound:gsub("/", "\\")
				sound = PATH.audio..sound
			else
				print("Неизвестный звук \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
				return false
			end
	
			arrSounds[#arrSounds+1] = sound
		end


		if type(arrSounds) == "table" and #arrSounds > 0 then
			lua_thread.create(playSounds, arrSounds, "userVolume", CFG.user[idUserEvent].isPlayRadioOn)
			return
		else
			print("Произошла ошибка в массиве \"sounds\" в пользовательском эвенте "..CFG.user[idUserEvent].name..", либо он не определён.!")
			return false
		end
	end

	if eventType == "call" then
		lua_thread.create(playSounds, {
			PATH.audio.."dispatcher_calls_units/we got a 10-.wav",
			randomChoice(DISPATCH_SOUNDS.codesWithIn),
			getAreaSoundPatch(vars.area)
		}, "callsVolume", true)

	elseif eventType == "areaAndCode" then
		lua_thread.create(playSounds, PATH.audio..PATH.areaAndCode..vars.area..".wav", "callsVolume")

	elseif eventType == "find" then
		lua_thread.create(playSounds, {
			DISPATCH_SOUNDS.suspect.lastSeen,
			DISPATCH_SOUNDS.words.inA,
			getAreaSoundPatch(vars.area),
			(
				vars["vehid"] and DISPATCH_SOUNDS.words.onA or
				vars["onFoot"] and DISPATCH_SOUNDS.suspect.onFoot or
				nil
			),
			unpack(getCarColorSound(vars.vehcolor)),
			getVehSound(vars.vehid)
		}, "findVolume", true)

	elseif eventType == "code1" then
		lua_thread.create(playSounds, randomChoice(CODE_1_SOUNDS), "radioVolume")

	elseif eventType == "code0" then
		lua_thread.create(playSounds, randomChoice(CODE_0_SOUNDS), "radioVolume")
	end

	return true
end

function getPatternWithoutVars(pattern)
	return pattern:gsub("@([%a_]+)", ".+")
end

function playSounds(array, volume, isPlayRadioOn)
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
	if tonumber(volume) then
		volume = tonumber(volume)
	elseif type(volume) == "string" then
		volume = INI.INI[volume]
	else
		volume = 1
	end

	setAudioStreamVolume(sound, volume)
	setAudioStreamState(sound, 1)
	return getAudioStreamLength(sound) * 1000 - 35
end

function getPlayerHandleOrIdByVariables(vars)
	local playerInStream, playerHandle

	playerId = vars["id"]
	if not playerId then
		playerId = sampGetPlayerIdByNickname(vars["nick"])
	end

	local _, ggId = sampGetPlayerIdByCharHandle(PLAYER_PED)
	if playerId ~= ggId then
		playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(playerId)
	else
		playerInStream, playerHandle = true, PLAYER_PED
	end

	return playerInStream and playerHandle or playerId
end

function getVehicleDefinedSoundByVariables(vars)

end

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
		elseif isValueIsInArray(vehId, CARS_TO_SOUND_TWO_COLORS) then
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
		print("Не найдена позиция маркера с id "..markerId.."!")
		return false 
	end

	for i, v in ipairs(AREAS) do
		if (markerPos.x >= v[2]) and (markerPos.y >= v[3]) and (markerPos.x <= v[5]) and (markerPos.y <= v[6]) then
			return v[1]
		end
	end
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
end

function getPlayerArea(ped)
	if getCharActiveInterior(ped) ~= 0 then return "San Andreas" end
	local x, y, _ = getCharCoordinates(ped)
	for i, v in ipairs(AREAS) do
		if (x >= v[2]) and (y >= v[3]) and (x <= v[5]) and (y <= v[6]) then
			return v[1]
		end
	end
end

function getCarModelByName(nameModel)
	for id, name in pairs(CAR_NAMES) do
		if name:tolower() == nameModel:tolower() then
			return id
		end
	end
	
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
				return loadAudioStream(PATH.audio..PATH.vehicles..class..".wav")
			end
		end
	end
end

function getCarColorSound(color)
	if type(color) == "string" then
		return {loadAudioStream(PATH.audio..PATH.colors..color..".wav")}
	end

	color = toTable(color)
	local sounds = {}
	local firstColor

	for _, c in ipairs(color) do
		if c ~= "Not sound" then

			for colorName, colorsArray in pairs(COLORS) do
				for _, idColor in ipairs(colorsArray) do
					if c == idColor then
						local t = colorName:split(" ")
						if t[#t] ~= firstColor then
							-- Есть light/dark
							if #t == 2 then
								sounds[#sounds+1] = loadAudioStream(
									PATH.audio..PATH.colors..t[1]..".wav"
								)
							end
							sounds[#sounds+1] = loadAudioStream(
								PATH.audio..PATH.colors..t[#t]..".wav"
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
	area = area:gsub("-", " "):gsub("_", " "):gsub("\"", ""):gsub("\'", "")

	local patch = PATH.audio..PATH.area..area..".wav"
	if doesFileExist(patch) then
		return patch
	else
		local newArea = AREAS_NOT_VOICED[area:tolower()]

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
			print("Района \""..area.."\" не найдено.")
			return false
		end
	end
end

function sampev.onSetMapIcon(id, pos, typeIcon, color, style)
	MAP_ICONS[#MAP_ICONS+1] = {
		id=id, 
		pos=pos, 
		type=typeIcon
	}
end

function sampev.onRemoveMapIcon(id)
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == id then
			MAP_ICONS[i] = nil
		end
	end
end

function sampev.onSetCheckpoint(pos, radius)
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "checkpoint" then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id="checkpoint",
		pos=pos,
		type=1
	}
end

function sampev.onDisableCheckpoint()
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "checkpoint" then
			MAP_ICONS[i] = nil
		end
	end
end

function sampev.onSetRaceCheckpoint(type, pos, nextPos, size)
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "racecheckpoint" then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id="racecheckpoint",
		pos=pos,
		type=2
	}
end

function sampev.onDisableRaceCheckpoint()
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "racecheckpoint" then
			MAP_ICONS[i] = nil
		end
	end
end

function isValueIsInArray(value, arr, isRegEx)
	for i, element in pairs(arr) do
		if type(i) == "string" then
			element = i
		end
		if type(value) == "string" and string.find(value:tolower(), element:tolower(), 1, not isRegEx) then
			return true
		elseif value == element then
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

function randomChoice(arr)
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

function toTable(var)
	if type(var) ~= "table" then
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

PATH = {
	config=getWorkingDirectory().."/config/PoliceDispatch/",
	audio=getWorkingDirectory().."/resource/PoliceDispatchAudio/"
}

function scandir(mask)
	local handle
	local t = {}
	handle, t[1] = findFirstFile(mask)
	for _ = 1, 1000 do
		t[#t+1] = findNextFile(handle)
		if not t[#t] then break end
	end

    return t
end
CODE_0_SOUNDS = scandir(PATH.audio..
	"broadcast_from_real_police_radio_recordings_in_critical_situations/*.mp3"
)
CODE_1_SOUNDS = scandir(PATH.audio..
	"broadcast_from_real_police_radio_recordings_in_shots_fired_situations/"..
	"*.mp3"
)

COLORS = {
	Blue={
		2, 7, 12, 10, 20, 28, 32, 39, 53, 54, 59, 67, 71, 75, 79, 87, 91, 93,
		94, 95, 97, 98, 100, 101, 103, 106, 108, 116, 116, 125, 130, 134, 135,
		139, 152, 155, 157, 162, 163, 165, 166, 198, 201, 203, 204, 208, 209,
		210, 217, 223, 240, 246, 255
	},
	Black={
		0, 36, 40, 127, 129, 133, 148, 164, 186, 205, 206, 215, 236
	},
	Brown={
		27, 30, 31, 36, 40, 47, 55, 57, 66, 84, 102, 104, 113, 119, 120, 123, 
		131, 132, 149, 159, 168, 172, 173, 174, 199, 200, 216, 218, 219, 224, 
		225, 230, 231, 238, 244
	},
	Copper={
		158, 180, 182, 183, 212, 222, 239, 242, 248, 249
	},
	Gold={
		6, 46, 61, 142, 194, 197, 214, 221, 228
	},
	Green={
		4, 9, 16, 37, 38, 44, 51, 52, 65, 73, 83, 86, 114, 137, 128, 145, 150,
		151, 153, 154, 160, 187, 188, 189, 191, 195, 202, 226, 227, 229, 234,
		235, 241, 243
	},
	Grey={
		8, 11, 13, 14, 15, 16, 19, 23, 24, 25, 26, 29, 33, 34, 35, 49, 50, 56, 
		60, 69, 72, 77, 81, 92, 99, 105, 107, 109, 110, 111, 112, 118, 122,
		138, 140, 141, 156, 185, 192, 193, 196, 207, 213, 247, 250, 251, 252,
		253, 254
	},
	Pink={
		5, 85, 126, 161, 220
	},
	Red={
		3, 17, 18, 21, 22, 42, 43, 45, 58, 62, 70, 74, 78, 80, 82, 88, 115,
		117, 121, 124, 175, 181
	},
	White={
		1, 14, 15, 63, 64, 68, 76, 89, 90, 96
	}
}

CARS_TO_SOUND_TWO_COLORS = {
	407, 416, 423, 424, 427, 428, 429, 431, 444, 460, 467, 471, 483, 487, 488, 
	489, 490, 494, 495, 496, 497, 498, 499, 502, 503, 505, 511, 512, 513, 522, 
	541, 542, 544, 549, 554, 573, 577, 582, 593, 592, 596, 597, 598, 599, 603, 
	609 
}

TABLE_OF_VEHICLES_WITHOUT_CHANGING_COLOR = {
	[406]="Silver", 
	[417]="Silver", 
	[425]="Green", 
	[432]="Do not say", 
	[434]="Customize", 
	[447]="Do not say", 
	[449]="Do not say", 
	[464]="Red", 
	[465]="Green", 
	[470]="Copper", 
	[486]="Do not say", 
	[501]="Brown", 
	[520]="Silver", 
	[523]="Silver", 
	[525]="White", 
	[528]="Blue", 
	[532]="Do not say", 
	[548]="Green", 
	[557]="Customize", 
	[557]="Customize", 
	[568]="Do not say", 
	[571]="Customize", 
	[601]="Blue" 
}

TYPE_OF_VEHICLE = {
	["2 Door"]={434, 542, 583},
	["4 Door"]={405, 421, 426, 445, 466, 467, 492, 507, 529, 540, 546, 547, 550,
	551, 580, 585, 604},
	["Ambulance"]={416},
	["Beach buggy"]={424},
	["Bike"]={481, 509, 510},
	["Boat"]={430, 453, 454, 472, 484, 493, 595},
	["Buggy"]={568},
	["Bulldozer"]={486},
	["Bus"]={431, 437},
	["Camper Van"]={508},
	["Combine Harvester"]={532},
	["Convertible"]={439, 480, 533, 555},
	["Coupe"]={401, 410, 436, 474, 475, 516, 517, 518, 526, 527, 545, 549},
	["Firetruck"]={407, 544},
	["Forklift"]={530},
	["Garbage Truck"]={408},
	["Go Kart"]={571},
	["Golf Car"]={457},
	["Hearse"]={442},
	["Helicopter"]={417, 425, 447, 465, 469, 487, 488, 496, 497, 501, 548, 563},
	["Hovercraft"]={539},
	["Icecream Van"]={423},
	["Jeep"]={400, 489, 579},
	["Lawn Mower"]={572, 485, 574},
	["Limo"]={409},
	["Lowrider"]={412, 419, 491, 534, 535, 536, 566, 567, 575, 576},
	["Moped"]={448, 462},
	["Motorbike"]={461, 463, 468, 521, 523, 581, 586},
	["Offroad"]={444, 470, 495, 500, 505, 556, 557, 573},
	["People Carrier"]={483},
	["Pickup"]={422, 543, 554, 600, 605},
	["Plane"]={464, 476, 511, 512, 513, 519, 520, 553, 577, 592, 593},
	["Police Car"]={490, 596, 597, 598, 599, 601},
	["Police Van"]={427},
	["Quad Bike"]={471},
	["Rubber Dinghy"]={473},
	["Sea Plane"]={460},
	["Speedboat"]={446, 452},
	["Sports Bike"]={522},
	["Sports Car"]={402, 411, 415, 429, 451, 477, 494, 502, 503, 504, 506, 541, 
	558, 559, 560, 562, 565, 587, 589, 602, 603},
	["Station Wagon"]={404, 418, 458, 479, 561},
	["Tank"]={432, 564},
	["Taxi"]={420, 438},
	["Tractor"]={531},
	["Train"]={537, 538, 570},
	["Tram"]={449},
	["Truck"]={403, 406, 443, 455, 514, 515, 524, 525, 528, 578},
	["Van"]={413, 414, 428, 433, 440, 456, 459, 478, 482, 498, 499, 552, 582, 588,
	609}
}

QUESTION_WORD_TABLE = {
	"что", "почему", "зачем", "куда", "кто", "когда", "где", "откуда", "чей",
	"как", "why", "what", "which", "who", "where", "when", "how"
}


local lu_rus, ul_rus = {}, {}
for i = 192, 223 do
	local A, a = string.char(i), string.char(i + 32)
	ul_rus[A] = a
	lu_rus[a] = A
end
function string.tolower(self)
	local s = self:lower()
	local len, res = #s, {}
	for i = 1, len do
		local ch = s:sub(i, i)
		res[i] = ul_rus[ch] or ch
	end
	return table.concat(res)
end

TABLE_OF_DISTRICTS_THAT_THE_DISPATCHER_DOES_NOT_VOICE = {
	["the strip"]="Las Venturas",
	["jefferson"]="East Los Santos",
	["pershing square"]="Commerce",
	["north rock"]="Northstar Rock",
	["shady cabin"]="Shady Creeks",
	["easter bay chemicals"]="Flint County",
	["yellow bell station"]="Prickle Pine",
	["conference center"]="Verdant Bluffs",
	["yellow bell gol course"]="Prickle Pine",
	["pilgrim"]="Julius Thruway East",
	["robada intersection"]="Tierra Robada",
	["hashbury"]="Hashberry",
	["royal casino"]="Royale Casino",
	["k.a.c.c. military fuels"]="Kacc Military Fuels",
	["sobell rail yards"]="Sobell Railyards",
	["pilson intersectiion"]="Pilson Intersection",
	["the big ear"]="The Big Ear Radiotelescope",
	["big ear"]="The Big Ear Radiotelescope",
	["creek"]="Julius Thruway East",
	["come-a-lot"]="Come A Lot",
	["mount chiliad"]="Mount Chilliad",
	["chilliad"]="Mount Chilliad",
	["chiliad"]="Mount Chilliad",
	["palisades"]="Pallisades",
	["restricted area"]="Bone County",
	["area 69"]="Bone County",
	["area 51"]="Bone County",
	["pirates in mens pants"]="Las Venturas"
}

TABLE_OF_DICTRICTS_SORTED_BY_8_LARGE_REGIONS = {
	["Bone County"]={
 		"Las Brujas",
 		"Regular Tom",
 		"El Castillo del Diablo",
 		"Green Palms",
 		"Las Payasadas",
 		"Lil' Probe Inn",
 		"'The Big Ear'",
 		"Verdant Meadows",
 		"Octane Springs",
 		"Fort Carson",
 		"Hunter Quarry",
 		"Restricted Area"
 	},
	["San Fierro"]={
 		"Avispa Country Club",
 		"Easter Bay Airport",
 		"Garcia",
 		"Esplanade East",
 		"Cranberry Station",
 		"Foster Valley",
 		"Queens",
 		"Gant Bridge",
 		"King's",
 		"Downtown",
 		"Ocean Flats",
 		"Easter Tunnel",
 		"Garver Bridge",
 		"Kincaid Bridge",
 		"Chinatown",
 		"Esplanade North",
 		"Battery Point",
 		"Doherty",
 		"City Hall",
 		"Hashbury",
 		"Santa Flora",
 		"Easter Basin",
 		"San Fierro Bay",
 		"Paradiso",
 		"Juniper Hill",
 		"Juniper Hollow",
 		"Financial",
 		"Calton Heights",
 		"Palisades",
 		"Missionary Hill",
 		"Mount Chiliad"
 	},
	["Los Santos"]={
 		"East Los Santos",
 		"Temple",
 		"Unity Station",
 		"Los Flores",
 		"Downtown Los Santos",
 		"Market Station",
 		"Jefferson",
 		"Mulholland",
 		"Rodeo",
 		"Little Mexico",
 		"Los Santos International",
 		"Richman",
 		"Conference Center",
 		"Las Colinas",
 		"Willowfield",
 		"Vinewood",
 		"Verona Beach",
 		"Commerce",
 		"Idlewood",
 		"Ocean Docks",
 		"Glen Park",
 		"Marina",
 		"Pershing Square",
 		"Market",
 		"Verdant Bluffs",
 		"East Beach",
 		"Ganton",
 		"El Corona",
 		"Playa del Seville",
 		"Santa Maria Beach"
 	},
	["Tierra Robada"]={
 		"Aldea Malvada",
 		"Kincaid Bridge",
 		"Garver Bridge",
 		"Bayside Marina",
 		"Robada Intersection",
 		"Las Barrancas",
 		"Sherman Reservoir",
 		"Valle Ocultado",
 		"Bayside Tunnel",
 		"Gant Bridge",
 		"El Quebrados",
 		"Arco del Oeste",
 		"The Sherman Dam",
 		"Bayside",
 		"San Fierro Bay"
 	},
	["Red County"]={
 		"Montgomery Intersection",
 		"Frederick Bridge",
 		"Montgomery",
 		"Hampton Barns",
 		"Martin Bridge",
 		"The Mako Span",
 		"Mulholland",
 		"Fallow Bridge",
 		"Easter Bay Chemicals",
 		"Richman",
 		"Hilltop Farm",
 		"Easter Bay Airport",
 		"Hankypanky Point",
 		"Flint Water",
 		"Blueberry",
 		"Dillimore",
 		"Fisher's Lagoon",
 		"San Andreas Sound",
 		"Fallen Tree",
 		"Palomino Creek",
 		"Fern Ridge",
 		"North Rock",
 		"The Panopticon"
 	},
	["Flint County"]={
 		"Easter Bay Chemicals",
 		"Beacon Hill",
 		"Flint Intersection",
 		"Leafy Hollow",
 		"The Farm",
 		"Flint Range",
 		"Los Santos Inlet",
 		"Back o Beyond"
 	},
	["Las Venturas"]={
 		"LVA Freight Depot",
 		"Blackfield Intersection",
 		"Starfish Casino",
 		"Linden Station",
 		"Yellow Bell Station",
 		"Julius Thruway West",
 		"Julius Thruway North",
 		"Redsands West",
 		"The Strip",
 		"Blackfield Chapel",
 		"Yellow Bell Gol Course",
 		"Las Venturas Airport",
 		"Julius Thruway East",
 		"Julius Thruway South",
 		"Roca Escalante",
 		"Redsands East",
 		"Greenglass College",
 		"Caligula's Palace",
 		"Pilgrim",
 		"The Clown's Pocket",
 		"Prickle Pine",
 		"Rockshore West",
 		"The Visage",
 		"The High Roller",
 		"Last Dime Motel",
 		"The Pink Swan",
 		"Linden Side",
 		"The Four Dragons Casino",
 		"Blackfield",
 		"Pirates in Men's Pants",
 		"Whitewood Estates",
 		"Royal Casino",
 		"K.A.C.C. Military Fuels",
 		"Harry Gold Parkway",
 		"Randolph Industrial Estate",
 		"Sobell Rail Yards",
 		"The Emerald Isle",
 		"Pilson Intersection",
 		"Spinybed",
 		"Rockshore East",
 		"The Camel's Toe",
 		"Old Venturas Strip",
 		"Creek",
 		"Come-A-Lot"
	},
	["Whetstone"]={
 		"Shady Cabin",
 		"Foster Valley",
 		"Shady Creeks",
 		"Angel Pine",
 		"Mount Chiliad"
 	}	
}

TABLE_OF_NAMES_DISTRICTS_AND_THEIR_COORDITATES = {
	{"Avispa Country Club", -2667.810, -302.135, -28.831, -2646.400, -262.320, 71.169},
    {"Easter Bay Airport", -1315.420, -405.388, 15.406, -1264.400, -209.543, 25.406},
    {"Avispa Country Club", -2550.040, -355.493, 0.000, -2470.040, -318.493, 39.700},
    {"Easter Bay Airport", -1490.330, -209.543, 15.406, -1264.400, -148.388, 25.406},
    {"Garcia", -2395.140, -222.589, -5.3, -2354.090, -204.792, 200.000},
    {"Shady Cabin", -1632.830, -2263.440, -3.0, -1601.330, -2231.790, 200.000},
    {"East Los Santos", 2381.680, -1494.030, -89.084, 2421.030, -1454.350, 110.916},
    {"LVA Freight Depot", 1236.630, 1163.410, -89.084, 1277.050, 1203.280, 110.916},
    {"Blackfield Intersection", 1277.050, 1044.690, -89.084, 1315.350, 1087.630, 110.916},
    {"Avispa Country Club", -2470.040, -355.493, 0.000, -2270.040, -318.493, 46.100},
    {"Temple", 1252.330, -926.999, -89.084, 1357.000, -910.170, 110.916},
    {"Unity Station", 1692.620, -1971.800, -20.492, 1812.620, -1932.800, 79.508},
    {"LVA Freight Depot", 1315.350, 1044.690, -89.084, 1375.600, 1087.630, 110.916},
    {"Los Flores", 2581.730, -1454.350, -89.084, 2632.830, -1393.420, 110.916},
    {"Starfish Casino", 2437.390, 1858.100, -39.084, 2495.090, 1970.850, 60.916},
    {"Easter Bay Chemicals", -1132.820, -787.391, 0.000, -956.476, -768.027, 200.000},
    {"Downtown Los Santos", 1370.850, -1170.870, -89.084, 1463.900, -1130.850, 110.916},
    {"Esplanade East", -1620.300, 1176.520, -4.5, -1580.010, 1274.260, 200.000},
    {"Market Station", 787.461, -1410.930, -34.126, 866.009, -1310.210, 65.874},
    {"Linden Station", 2811.250, 1229.590, -39.594, 2861.250, 1407.590, 60.406},
    {"Montgomery Intersection", 1582.440, 347.457, 0.000, 1664.620, 401.750, 200.000},
    {"Frederick Bridge", 2759.250, 296.501, 0.000, 2774.250, 594.757, 200.000},
    {"Yellow Bell Station", 1377.480, 2600.430, -21.926, 1492.450, 2687.360, 78.074},
    {"Downtown Los Santos", 1507.510, -1385.210, 110.916, 1582.550, -1325.310, 335.916},
    {"Jefferson", 2185.330, -1210.740, -89.084, 2281.450, -1154.590, 110.916},
    {"Mulholland", 1318.130, -910.170, -89.084, 1357.000, -768.027, 110.916},
    {"Avispa Country Club", -2361.510, -417.199, 0.000, -2270.040, -355.493, 200.000},
    {"Jefferson", 1996.910, -1449.670, -89.084, 2056.860, -1350.720, 110.916},
    {"Julius Thruway West", 1236.630, 2142.860, -89.084, 1297.470, 2243.230, 110.916},
    {"Jefferson", 2124.660, -1494.030, -89.084, 2266.210, -1449.670, 110.916},
    {"Julius Thruway North", 1848.400, 2478.490, -89.084, 1938.800, 2553.490, 110.916},
    {"Rodeo", 422.680, -1570.200, -89.084, 466.223, -1406.050, 110.916},
    {"Cranberry Station", -2007.830, 56.306, 0.000, -1922.000, 224.782, 100.000},
    {"Downtown Los Santos", 1391.050, -1026.330, -89.084, 1463.900, -926.999, 110.916},
    {"Redsands West", 1704.590, 2243.230, -89.084, 1777.390, 2342.830, 110.916},
    {"Little Mexico", 1758.900, -1722.260, -89.084, 1812.620, -1577.590, 110.916},
    {"Blackfield Intersection", 1375.600, 823.228, -89.084, 1457.390, 919.447, 110.916},
    {"Los Santos International", 1974.630, -2394.330, -39.084, 2089.000, -2256.590, 60.916},
    {"Beacon Hill", -399.633, -1075.520, -1.489, -319.033, -977.516, 198.511},
    {"Rodeo", 334.503, -1501.950, -89.084, 422.680, -1406.050, 110.916},
    {"Richman", 225.165, -1369.620, -89.084, 334.503, -1292.070, 110.916},
    {"Downtown Los Santos", 1724.760, -1250.900, -89.084, 1812.620, -1150.870, 110.916},
    {"The Strip", 2027.400, 1703.230, -89.084, 2137.400, 1783.230, 110.916},
    {"Downtown Los Santos", 1378.330, -1130.850, -89.084, 1463.900, -1026.330, 110.916},
    {"Blackfield Intersection", 1197.390, 1044.690, -89.084, 1277.050, 1163.390, 110.916},
    {"Conference Center", 1073.220, -1842.270, -89.084, 1323.900, -1804.210, 110.916},
    {"Montgomery", 1451.400, 347.457, -6.1, 1582.440, 420.802, 200.000},
    {"Foster Valley", -2270.040, -430.276, -1.2, -2178.690, -324.114, 200.000},
    {"Blackfield Chapel", 1325.600, 596.349, -89.084, 1375.600, 795.010, 110.916},
    {"Los Santos International", 2051.630, -2597.260, -39.084, 2152.450, -2394.330, 60.916},
    {"Mulholland", 1096.470, -910.170, -89.084, 1169.130, -768.027, 110.916},
    {"Yellow Bell Gol Course", 1457.460, 2723.230, -89.084, 1534.560, 2863.230, 110.916},
    {"The Strip", 2027.400, 1783.230, -89.084, 2162.390, 1863.230, 110.916},
    {"Jefferson", 2056.860, -1210.740, -89.084, 2185.330, -1126.320, 110.916},
    {"Mulholland", 952.604, -937.184, -89.084, 1096.470, -860.619, 110.916},
    {"Aldea Malvada", -1372.140, 2498.520, 0.000, -1277.590, 2615.350, 200.000},
    {"Las Colinas", 2126.860, -1126.320, -89.084, 2185.330, -934.489, 110.916},
    {"Las Colinas", 1994.330, -1100.820, -89.084, 2056.860, -920.815, 110.916},
    {"Richman", 647.557, -954.662, -89.084, 768.694, -860.619, 110.916},
    {"LVA Freight Depot", 1277.050, 1087.630, -89.084, 1375.600, 1203.280, 110.916},
    {"Julius Thruway North", 1377.390, 2433.230, -89.084, 1534.560, 2507.230, 110.916},
    {"Willowfield", 2201.820, -2095.000, -89.084, 2324.000, -1989.900, 110.916},
    {"Julius Thruway North", 1704.590, 2342.830, -89.084, 1848.400, 2433.230, 110.916},
    {"Temple", 1252.330, -1130.850, -89.084, 1378.330, -1026.330, 110.916},
    {"Little Mexico", 1701.900, -1842.270, -89.084, 1812.620, -1722.260, 110.916},
    {"Queens", -2411.220, 373.539, 0.000, -2253.540, 458.411, 200.000},
    {"Las Venturas Airport", 1515.810, 1586.400, -12.500, 1729.950, 1714.560, 87.500},
    {"Richman", 225.165, -1292.070, -89.084, 466.223, -1235.070, 110.916},
    {"Temple", 1252.330, -1026.330, -89.084, 1391.050, -926.999, 110.916},
    {"East Los Santos", 2266.260, -1494.030, -89.084, 2381.680, -1372.040, 110.916},
    {"Julius Thruway East", 2623.180, 943.235, -89.084, 2749.900, 1055.960, 110.916},
    {"Willowfield", 2541.700, -1941.400, -89.084, 2703.580, -1852.870, 110.916},
    {"Las Colinas", 2056.860, -1126.320, -89.084, 2126.860, -920.815, 110.916},
    {"Julius Thruway East", 2625.160, 2202.760, -89.084, 2685.160, 2442.550, 110.916},
    {"Rodeo", 225.165, -1501.950, -89.084, 334.503, -1369.620, 110.916},
    {"Las Brujas", -365.167, 2123.010, -3.0, -208.570, 2217.680, 200.000},
    {"Julius Thruway East", 2536.430, 2442.550, -89.084, 2685.160, 2542.550, 110.916},
    {"Rodeo", 334.503, -1406.050, -89.084, 466.223, -1292.070, 110.916},
    {"Vinewood", 647.557, -1227.280, -89.084, 787.461, -1118.280, 110.916},
    {"Rodeo", 422.680, -1684.650, -89.084, 558.099, -1570.200, 110.916},
    {"Julius Thruway North", 2498.210, 2542.550, -89.084, 2685.160, 2626.550, 110.916},
    {"Downtown Los Santos", 1724.760, -1430.870, -89.084, 1812.620, -1250.900, 110.916},
    {"Rodeo", 225.165, -1684.650, -89.084, 312.803, -1501.950, 110.916},
    {"Jefferson", 2056.860, -1449.670, -89.084, 2266.210, -1372.040, 110.916},
    {"Hampton Barns", 603.035, 264.312, 0.000, 761.994, 366.572, 200.000},
    {"Temple", 1096.470, -1130.840, -89.084, 1252.330, -1026.330, 110.916},
    {"Kincaid Bridge", -1087.930, 855.370, -89.084, -961.950, 986.281, 110.916},
    {"Verona Beach", 1046.150, -1722.260, -89.084, 1161.520, -1577.590, 110.916},
    {"Commerce", 1323.900, -1722.260, -89.084, 1440.900, -1577.590, 110.916},
    {"Mulholland", 1357.000, -926.999, -89.084, 1463.900, -768.027, 110.916},
    {"Rodeo", 466.223, -1570.200, -89.084, 558.099, -1385.070, 110.916},
    {"Mulholland", 911.802, -860.619, -89.084, 1096.470, -768.027, 110.916},
    {"Mulholland", 768.694, -954.662, -89.084, 952.604, -860.619, 110.916},
    {"Julius Thruway South", 2377.390, 788.894, -89.084, 2537.390, 897.901, 110.916},
    {"Idlewood", 1812.620, -1852.870, -89.084, 1971.660, -1742.310, 110.916},
    {"Ocean Docks", 2089.000, -2394.330, -89.084, 2201.820, -2235.840, 110.916},
    {"Commerce", 1370.850, -1577.590, -89.084, 1463.900, -1384.950, 110.916},
    {"Julius Thruway North", 2121.400, 2508.230, -89.084, 2237.400, 2663.170, 110.916},
    {"Temple", 1096.470, -1026.330, -89.084, 1252.330, -910.170, 110.916},
    {"Glen Park", 1812.620, -1449.670, -89.084, 1996.910, -1350.720, 110.916},
    {"Easter Bay Airport", -1242.980, -50.096, 0.000, -1213.910, 578.396, 200.000},
    {"Martin Bridge", -222.179, 293.324, 0.000, -122.126, 476.465, 200.000},
    {"The Strip", 2106.700, 1863.230, -89.084, 2162.390, 2202.760, 110.916},
    {"Willowfield", 2541.700, -2059.230, -89.084, 2703.580, -1941.400, 110.916},
    {"Marina", 807.922, -1577.590, -89.084, 926.922, -1416.250, 110.916},
    {"Las Venturas Airport", 1457.370, 1143.210, -89.084, 1777.400, 1203.280, 110.916},
    {"Idlewood", 1812.620, -1742.310, -89.084, 1951.660, -1602.310, 110.916},
    {"Esplanade East", -1580.010, 1025.980, -6.1, -1499.890, 1274.260, 200.000},
    {"Downtown Los Santos", 1370.850, -1384.950, -89.084, 1463.900, -1170.870, 110.916},
    {"The Mako Span", 1664.620, 401.750, 0.000, 1785.140, 567.203, 200.000},
    {"Rodeo", 312.803, -1684.650, -89.084, 422.680, -1501.950, 110.916},
    {"Pershing Square", 1440.900, -1722.260, -89.084, 1583.500, -1577.590, 110.916},
    {"Mulholland", 687.802, -860.619, -89.084, 911.802, -768.027, 110.916},
    {"Gant Bridge", -2741.070, 1490.470, -6.1, -2616.400, 1659.680, 200.000},
    {"Las Colinas", 2185.330, -1154.590, -89.084, 2281.450, -934.489, 110.916},
    {"Mulholland", 1169.130, -910.170, -89.084, 1318.130, -768.027, 110.916},
    {"Julius Thruway North", 1938.800, 2508.230, -89.084, 2121.400, 2624.230, 110.916},
    {"Commerce", 1667.960, -1577.590, -89.084, 1812.620, -1430.870, 110.916},
    {"Rodeo", 72.648, -1544.170, -89.084, 225.165, -1404.970, 110.916},
    {"Roca Escalante", 2536.430, 2202.760, -89.084, 2625.160, 2442.550, 110.916},
    {"Rodeo", 72.648, -1684.650, -89.084, 225.165, -1544.170, 110.916},
    {"Market", 952.663, -1310.210, -89.084, 1072.660, -1130.850, 110.916},
    {"Las Colinas", 2632.740, -1135.040, -89.084, 2747.740, -945.035, 110.916},
    {"Mulholland", 861.085, -674.885, -89.084, 1156.550, -600.896, 110.916},
    {"King's", -2253.540, 373.539, -9.1, -1993.280, 458.411, 200.000},
    {"Redsands East", 1848.400, 2342.830, -89.084, 2011.940, 2478.490, 110.916},
    {"Downtown", -1580.010, 744.267, -6.1, -1499.890, 1025.980, 200.000},
    {"Conference Center", 1046.150, -1804.210, -89.084, 1323.900, -1722.260, 110.916},
    {"Richman", 647.557, -1118.280, -89.084, 787.461, -954.662, 110.916},
    {"Ocean Flats", -2994.490, 277.411, -9.1, -2867.850, 458.411, 200.000},
    {"Greenglass College", 964.391, 930.890, -89.084, 1166.530, 1044.690, 110.916},
    {"Glen Park", 1812.620, -1100.820, -89.084, 1994.330, -973.380, 110.916},
    {"LVA Freight Depot", 1375.600, 919.447, -89.084, 1457.370, 1203.280, 110.916},
    {"Regular Tom", -405.770, 1712.860, -3.0, -276.719, 1892.750, 200.000},
    {"Verona Beach", 1161.520, -1722.260, -89.084, 1323.900, -1577.590, 110.916},
    {"East Los Santos", 2281.450, -1372.040, -89.084, 2381.680, -1135.040, 110.916},
    {"Caligula's Palace", 2137.400, 1703.230, -89.084, 2437.390, 1783.230, 110.916},
    {"Idlewood", 1951.660, -1742.310, -89.084, 2124.660, -1602.310, 110.916},
    {"Pilgrim", 2624.400, 1383.230, -89.084, 2685.160, 1783.230, 110.916},
    {"Idlewood", 2124.660, -1742.310, -89.084, 2222.560, -1494.030, 110.916},
    {"Queens", -2533.040, 458.411, 0.000, -2329.310, 578.396, 200.000},
    {"Downtown", -1871.720, 1176.420, -4.5, -1620.300, 1274.260, 200.000},
    {"Commerce", 1583.500, -1722.260, -89.084, 1758.900, -1577.590, 110.916},
    {"East Los Santos", 2381.680, -1454.350, -89.084, 2462.130, -1135.040, 110.916},
    {"Marina", 647.712, -1577.590, -89.084, 807.922, -1416.250, 110.916},
    {"Richman", 72.648, -1404.970, -89.084, 225.165, -1235.070, 110.916},
    {"Vinewood", 647.712, -1416.250, -89.084, 787.461, -1227.280, 110.916},
    {"East Los Santos", 2222.560, -1628.530, -89.084, 2421.030, -1494.030, 110.916},
    {"Rodeo", 558.099, -1684.650, -89.084, 647.522, -1384.930, 110.916},
    {"Easter Tunnel", -1709.710, -833.034, -1.5, -1446.010, -730.118, 200.000},
    {"Rodeo", 466.223, -1385.070, -89.084, 647.522, -1235.070, 110.916},
    {"Redsands East", 1817.390, 2202.760, -89.084, 2011.940, 2342.830, 110.916},
    {"The Clown's Pocket", 2162.390, 1783.230, -89.084, 2437.390, 1883.230, 110.916},
    {"Idlewood", 1971.660, -1852.870, -89.084, 2222.560, -1742.310, 110.916},
    {"Montgomery Intersection", 1546.650, 208.164, 0.000, 1745.830, 347.457, 200.000},
    {"Willowfield", 2089.000, -2235.840, -89.084, 2201.820, -1989.900, 110.916},
    {"Temple", 952.663, -1130.840, -89.084, 1096.470, -937.184, 110.916},
    {"Prickle Pine", 1848.400, 2553.490, -89.084, 1938.800, 2863.230, 110.916},
    {"Los Santos International", 1400.970, -2669.260, -39.084, 2189.820, -2597.260, 60.916},
    {"Garver Bridge", -1213.910, 950.022, -89.084, -1087.930, 1178.930, 110.916},
    {"Garver Bridge", -1339.890, 828.129, -89.084, -1213.910, 1057.040, 110.916},
    {"Kincaid Bridge", -1339.890, 599.218, -89.084, -1213.910, 828.129, 110.916},
    {"Kincaid Bridge", -1213.910, 721.111, -89.084, -1087.930, 950.022, 110.916},
    {"Verona Beach", 930.221, -2006.780, -89.084, 1073.220, -1804.210, 110.916},
    {"Verdant Bluffs", 1073.220, -2006.780, -89.084, 1249.620, -1842.270, 110.916},
    {"Vinewood", 787.461, -1130.840, -89.084, 952.604, -954.662, 110.916},
    {"Vinewood", 787.461, -1310.210, -89.084, 952.663, -1130.840, 110.916},
    {"Commerce", 1463.900, -1577.590, -89.084, 1667.960, -1430.870, 110.916},
    {"Market", 787.461, -1416.250, -89.084, 1072.660, -1310.210, 110.916},
    {"Rockshore West", 2377.390, 596.349, -89.084, 2537.390, 788.894, 110.916},
    {"Julius Thruway North", 2237.400, 2542.550, -89.084, 2498.210, 2663.170, 110.916},
    {"East Beach", 2632.830, -1668.130, -89.084, 2747.740, -1393.420, 110.916},
    {"Fallow Bridge", 434.341, 366.572, 0.000, 603.035, 555.680, 200.000},
    {"Willowfield", 2089.000, -1989.900, -89.084, 2324.000, -1852.870, 110.916},
    {"Chinatown", -2274.170, 578.396, -7.6, -2078.670, 744.170, 200.000},
    {"El Castillo del Diablo", -208.570, 2337.180, 0.000, 8.430, 2487.180, 200.000},
    {"Ocean Docks", 2324.000, -2145.100, -89.084, 2703.580, -2059.230, 110.916},
    {"Easter Bay Chemicals", -1132.820, -768.027, 0.000, -956.476, -578.118, 200.000},
    {"The Visage", 1817.390, 1703.230, -89.084, 2027.400, 1863.230, 110.916},
    {"Ocean Flats", -2994.490, -430.276, -1.2, -2831.890, -222.589, 200.000},
    {"Richman", 321.356, -860.619, -89.084, 687.802, -768.027, 110.916},
    {"Green Palms", 176.581, 1305.450, -3.0, 338.658, 1520.720, 200.000},
    {"Richman", 321.356, -768.027, -89.084, 700.794, -674.885, 110.916},
    {"Starfish Casino", 2162.390, 1883.230, -89.084, 2437.390, 2012.180, 110.916},
    {"East Beach", 2747.740, -1668.130, -89.084, 2959.350, -1498.620, 110.916},
    {"Jefferson", 2056.860, -1372.040, -89.084, 2281.450, -1210.740, 110.916},
    {"Downtown Los Santos", 1463.900, -1290.870, -89.084, 1724.760, -1150.870, 110.916},
    {"Downtown Los Santos", 1463.900, -1430.870, -89.084, 1724.760, -1290.870, 110.916},
    {"Garver Bridge", -1499.890, 696.442, -179.615, -1339.890, 925.353, 20.385},
    {"Julius Thruway South", 1457.390, 823.228, -89.084, 2377.390, 863.229, 110.916},
    {"East Los Santos", 2421.030, -1628.530, -89.084, 2632.830, -1454.350, 110.916},
    {"Greenglass College", 964.391, 1044.690, -89.084, 1197.390, 1203.220, 110.916},
    {"Las Colinas", 2747.740, -1120.040, -89.084, 2959.350, -945.035, 110.916},
    {"Mulholland", 737.573, -768.027, -89.084, 1142.290, -674.885, 110.916},
    {"Ocean Docks", 2201.820, -2730.880, -89.084, 2324.000, -2418.330, 110.916},
    {"East Los Santos", 2462.130, -1454.350, -89.084, 2581.730, -1135.040, 110.916},
    {"Ganton", 2222.560, -1722.330, -89.084, 2632.830, -1628.530, 110.916},
    {"Avispa Country Club", -2831.890, -430.276, -6.1, -2646.400, -222.589, 200.000},
    {"Willowfield", 1970.620, -2179.250, -89.084, 2089.000, -1852.870, 110.916},
    {"Esplanade North", -1982.320, 1274.260, -4.5, -1524.240, 1358.900, 200.000},
    {"The High Roller", 1817.390, 1283.230, -89.084, 2027.390, 1469.230, 110.916},
    {"Ocean Docks", 2201.820, -2418.330, -89.084, 2324.000, -2095.000, 110.916},
    {"Last Dime Motel", 1823.080, 596.349, -89.084, 1997.220, 823.228, 110.916},
    {"Bayside Marina", -2353.170, 2275.790, 0.000, -2153.170, 2475.790, 200.000},
    {"King's", -2329.310, 458.411, -7.6, -1993.280, 578.396, 200.000},
    {"El Corona", 1692.620, -2179.250, -89.084, 1812.620, -1842.270, 110.916},
    {"Blackfield Chapel", 1375.600, 596.349, -89.084, 1558.090, 823.228, 110.916},
    {"The Pink Swan", 1817.390, 1083.230, -89.084, 2027.390, 1283.230, 110.916},
    {"Julius Thruway West", 1197.390, 1163.390, -89.084, 1236.630, 2243.230, 110.916},
    {"Los Flores", 2581.730, -1393.420, -89.084, 2747.740, -1135.040, 110.916},
    {"The Visage", 1817.390, 1863.230, -89.084, 2106.700, 2011.830, 110.916},
    {"Prickle Pine", 1938.800, 2624.230, -89.084, 2121.400, 2861.550, 110.916},
    {"Verona Beach", 851.449, -1804.210, -89.084, 1046.150, -1577.590, 110.916},
    {"Robada Intersection", -1119.010, 1178.930, -89.084, -862.025, 1351.450, 110.916},
    {"Linden Side", 2749.900, 943.235, -89.084, 2923.390, 1198.990, 110.916},
    {"Ocean Docks", 2703.580, -2302.330, -89.084, 2959.350, -2126.900, 110.916},
    {"Willowfield", 2324.000, -2059.230, -89.084, 2541.700, -1852.870, 110.916},
    {"King's", -2411.220, 265.243, -9.1, -1993.280, 373.539, 200.000},
    {"Commerce", 1323.900, -1842.270, -89.084, 1701.900, -1722.260, 110.916},
    {"Mulholland", 1269.130, -768.027, -89.084, 1414.070, -452.425, 110.916},
    {"Marina", 647.712, -1804.210, -89.084, 851.449, -1577.590, 110.916},
    {"Battery Point", -2741.070, 1268.410, -4.5, -2533.040, 1490.470, 200.000},
    {"The Four Dragons Casino", 1817.390, 863.232, -89.084, 2027.390, 1083.230, 110.916},
    {"Blackfield", 964.391, 1203.220, -89.084, 1197.390, 1403.220, 110.916},
    {"Julius Thruway North", 1534.560, 2433.230, -89.084, 1848.400, 2583.230, 110.916},
    {"Yellow Bell Gol Course", 1117.400, 2723.230, -89.084, 1457.460, 2863.230, 110.916},
    {"Idlewood", 1812.620, -1602.310, -89.084, 2124.660, -1449.670, 110.916},
    {"Redsands West", 1297.470, 2142.860, -89.084, 1777.390, 2243.230, 110.916},
    {"Doherty", -2270.040, -324.114, -1.2, -1794.920, -222.589, 200.000},
    {"Hilltop Farm", 967.383, -450.390, -3.0, 1176.780, -217.900, 200.000},
    {"Las Barrancas", -926.130, 1398.730, -3.0, -719.234, 1634.690, 200.000},
    {"Pirates in Men's Pants", 1817.390, 1469.230, -89.084, 2027.400, 1703.230, 110.916},
    {"City Hall", -2867.850, 277.411, -9.1, -2593.440, 458.411, 200.000},
    {"Avispa Country Club", -2646.400, -355.493, 0.000, -2270.040, -222.589, 200.000},
    {"The Strip", 2027.400, 863.229, -89.084, 2087.390, 1703.230, 110.916},
    {"Hashbury", -2593.440, -222.589, -1.0, -2411.220, 54.722, 200.000},
    {"Los Santos International", 1852.000, -2394.330, -89.084, 2089.000, -2179.250, 110.916},
    {"Whitewood Estates", 1098.310, 1726.220, -89.084, 1197.390, 2243.230, 110.916},
    {"Sherman Reservoir", -789.737, 1659.680, -89.084, -599.505, 1929.410, 110.916},
    {"El Corona", 1812.620, -2179.250, -89.084, 1970.620, -1852.870, 110.916},
    {"Downtown", -1700.010, 744.267, -6.1, -1580.010, 1176.520, 200.000},
    {"Foster Valley", -2178.690, -1250.970, 0.000, -1794.920, -1115.580, 200.000},
    {"Las Payasadas", -354.332, 2580.360, 2.0, -133.625, 2816.820, 200.000},
    {"Valle Ocultado", -936.668, 2611.440, 2.0, -715.961, 2847.900, 200.000},
    {"Blackfield Intersection", 1166.530, 795.010, -89.084, 1375.600, 1044.690, 110.916},
    {"Ganton", 2222.560, -1852.870, -89.084, 2632.830, -1722.330, 110.916},
    {"Easter Bay Airport", -1213.910, -730.118, 0.000, -1132.820, -50.096, 200.000},
    {"Redsands East", 1817.390, 2011.830, -89.084, 2106.700, 2202.760, 110.916},
    {"Esplanade East", -1499.890, 578.396, -79.615, -1339.890, 1274.260, 20.385},
    {"Caligula's Palace", 2087.390, 1543.230, -89.084, 2437.390, 1703.230, 110.916},
    {"Royal Casino", 2087.390, 1383.230, -89.084, 2437.390, 1543.230, 110.916},
    {"Richman", 72.648, -1235.070, -89.084, 321.356, -1008.150, 110.916},
    {"Starfish Casino", 2437.390, 1783.230, -89.084, 2685.160, 2012.180, 110.916},
    {"Mulholland", 1281.130, -452.425, -89.084, 1641.130, -290.913, 110.916},
    {"Downtown", -1982.320, 744.170, -6.1, -1871.720, 1274.260, 200.000},
    {"Hankypanky Point", 2576.920, 62.158, 0.000, 2759.250, 385.503, 200.000},
    {"K.A.C.C. Military Fuels", 2498.210, 2626.550, -89.084, 2749.900, 2861.550, 110.916},
    {"Harry Gold Parkway", 1777.390, 863.232, -89.084, 1817.390, 2342.830, 110.916},
    {"Bayside Tunnel", -2290.190, 2548.290, -89.084, -1950.190, 2723.290, 110.916},
    {"Ocean Docks", 2324.000, -2302.330, -89.084, 2703.580, -2145.100, 110.916},
    {"Richman", 321.356, -1044.070, -89.084, 647.557, -860.619, 110.916},
    {"Randolph Industrial Estate", 1558.090, 596.349, -89.084, 1823.080, 823.235, 110.916},
    {"East Beach", 2632.830, -1852.870, -89.084, 2959.350, -1668.130, 110.916},
    {"Flint Water", -314.426, -753.874, -89.084, -106.339, -463.073, 110.916},
    {"Blueberry", 19.607, -404.136, 3.8, 349.607, -220.137, 200.000},
    {"Linden Station", 2749.900, 1198.990, -89.084, 2923.390, 1548.990, 110.916},
    {"Glen Park", 1812.620, -1350.720, -89.084, 2056.860, -1100.820, 110.916},
    {"Downtown", -1993.280, 265.243, -9.1, -1794.920, 578.396, 200.000},
    {"Redsands West", 1377.390, 2243.230, -89.084, 1704.590, 2433.230, 110.916},
    {"Richman", 321.356, -1235.070, -89.084, 647.522, -1044.070, 110.916},
    {"Gant Bridge", -2741.450, 1659.680, -6.1, -2616.400, 2175.150, 200.000},
    {"Lil' Probe Inn", -90.218, 1286.850, -3.0, 153.859, 1554.120, 200.000},
    {"Flint Intersection", -187.700, -1596.760, -89.084, 17.063, -1276.600, 110.916},
    {"Las Colinas", 2281.450, -1135.040, -89.084, 2632.740, -945.035, 110.916},
    {"Sobell Rail Yards", 2749.900, 1548.990, -89.084, 2923.390, 1937.250, 110.916},
    {"The Emerald Isle", 2011.940, 2202.760, -89.084, 2237.400, 2508.230, 110.916},
    {"El Castillo del Diablo", -208.570, 2123.010, -7.6, 114.033, 2337.180, 200.000},
    {"Santa Flora", -2741.070, 458.411, -7.6, -2533.040, 793.411, 200.000},
    {"Playa del Seville", 2703.580, -2126.900, -89.084, 2959.350, -1852.870, 110.916},
    {"Market", 926.922, -1577.590, -89.084, 1370.850, -1416.250, 110.916},
    {"Queens", -2593.440, 54.722, 0.000, -2411.220, 458.411, 200.000},
    {"Pilson Intersection", 1098.390, 2243.230, -89.084, 1377.390, 2507.230, 110.916},
    {"Spinybed", 2121.400, 2663.170, -89.084, 2498.210, 2861.550, 110.916},
    {"Pilgrim", 2437.390, 1383.230, -89.084, 2624.400, 1783.230, 110.916},
    {"Blackfield", 964.391, 1403.220, -89.084, 1197.390, 1726.220, 110.916},
    {"'The Big Ear'", -410.020, 1403.340, -3.0, -137.969, 1681.230, 200.000},
    {"Dillimore", 580.794, -674.885, -9.5, 861.085, -404.790, 200.000},
    {"El Quebrados", -1645.230, 2498.520, 0.000, -1372.140, 2777.850, 200.000},
    {"Esplanade North", -2533.040, 1358.900, -4.5, -1996.660, 1501.210, 200.000},
    {"Easter Bay Airport", -1499.890, -50.096, -1.0, -1242.980, 249.904, 200.000},
    {"Fisher's Lagoon", 1916.990, -233.323, -100.000, 2131.720, 13.800, 200.000},
    {"Mulholland", 1414.070, -768.027, -89.084, 1667.610, -452.425, 110.916},
    {"East Beach", 2747.740, -1498.620, -89.084, 2959.350, -1120.040, 110.916},
    {"San Andreas Sound", 2450.390, 385.503, -100.000, 2759.250, 562.349, 200.000},
    {"Shady Creeks", -2030.120, -2174.890, -6.1, -1820.640, -1771.660, 200.000},
    {"Market", 1072.660, -1416.250, -89.084, 1370.850, -1130.850, 110.916},
    {"Rockshore West", 1997.220, 596.349, -89.084, 2377.390, 823.228, 110.916},
    {"Prickle Pine", 1534.560, 2583.230, -89.084, 1848.400, 2863.230, 110.916},
    {"Easter Basin", -1794.920, -50.096, -1.04, -1499.890, 249.904, 200.000},
    {"Leafy Hollow", -1166.970, -1856.030, 0.000, -815.624, -1602.070, 200.000},
    {"LVA Freight Depot", 1457.390, 863.229, -89.084, 1777.400, 1143.210, 110.916},
    {"Prickle Pine", 1117.400, 2507.230, -89.084, 1534.560, 2723.230, 110.916},
    {"Blueberry", 104.534, -220.137, 2.3, 349.607, 152.236, 200.000},
    {"El Castillo del Diablo", -464.515, 2217.680, 0.000, -208.570, 2580.360, 200.000},
    {"Downtown", -2078.670, 578.396, -7.6, -1499.890, 744.267, 200.000},
    {"Rockshore East", 2537.390, 676.549, -89.084, 2902.350, 943.235, 110.916},
    {"San Fierro Bay", -2616.400, 1501.210, -3.0, -1996.660, 1659.680, 200.000},
    {"Paradiso", -2741.070, 793.411, -6.1, -2533.040, 1268.410, 200.000},
    {"The Camel's Toe", 2087.390, 1203.230, -89.084, 2640.400, 1383.230, 110.916},
    {"Old Venturas Strip", 2162.390, 2012.180, -89.084, 2685.160, 2202.760, 110.916},
    {"Juniper Hill", -2533.040, 578.396, -7.6, -2274.170, 968.369, 200.000},
    {"Juniper Hollow", -2533.040, 968.369, -6.1, -2274.170, 1358.900, 200.000},
    {"Roca Escalante", 2237.400, 2202.760, -89.084, 2536.430, 2542.550, 110.916},
    {"Julius Thruway East", 2685.160, 1055.960, -89.084, 2749.900, 2626.550, 110.916},
    {"Verona Beach", 647.712, -2173.290, -89.084, 930.221, -1804.210, 110.916},
    {"Foster Valley", -2178.690, -599.884, -1.2, -1794.920, -324.114, 200.000},
    {"Arco del Oeste", -901.129, 2221.860, 0.000, -592.090, 2571.970, 200.000},
    {"Fallen Tree", -792.254, -698.555, -5.3, -452.404, -380.043, 200.000},
    {"The Farm", -1209.670, -1317.100, 114.981, -908.161, -787.391, 251.981},
    {"The Sherman Dam", -968.772, 1929.410, -3.0, -481.126, 2155.260, 200.000},
    {"Esplanade North", -1996.660, 1358.900, -4.5, -1524.240, 1592.510, 200.000},
    {"Financial", -1871.720, 744.170, -6.1, -1701.300, 1176.420, 300.000},
    {"Garcia", -2411.220, -222.589, -1.14, -2173.040, 265.243, 200.000},
    {"Montgomery", 1119.510, 119.526, -3.0, 1451.400, 493.323, 200.000},
    {"Creek", 2749.900, 1937.250, -89.084, 2921.620, 2669.790, 110.916},
    {"Los Santos International", 1249.620, -2394.330, -89.084, 1852.000, -2179.250, 110.916},
    {"Santa Maria Beach", 72.648, -2173.290, -89.084, 342.648, -1684.650, 110.916},
    {"Mulholland Intersection", 1463.900, -1150.870, -89.084, 1812.620, -768.027, 110.916},
    {"Angel Pine", -2324.940, -2584.290, -6.1, -1964.220, -2212.110, 200.000},
    {"Verdant Meadows", 37.032, 2337.180, -3.0, 435.988, 2677.900, 200.000},
    {"Octane Springs", 338.658, 1228.510, 0.000, 664.308, 1655.050, 200.000},
    {"Come-A-Lot", 2087.390, 943.235, -89.084, 2623.180, 1203.230, 110.916},
    {"Redsands West", 1236.630, 1883.110, -89.084, 1777.390, 2142.860, 110.916},
    {"Santa Maria Beach", 342.648, -2173.290, -89.084, 647.712, -1684.650, 110.916},
    {"Verdant Bluffs", 1249.620, -2179.250, -89.084, 1692.620, -1842.270, 110.916},
    {"Las Venturas Airport", 1236.630, 1203.280, -89.084, 1457.370, 1883.110, 110.916},
    {"Flint Range", -594.191, -1648.550, 0.000, -187.700, -1276.600, 200.000},
    {"Verdant Bluffs", 930.221, -2488.420, -89.084, 1249.620, -2006.780, 110.916},
    {"Palomino Creek", 2160.220, -149.004, 0.000, 2576.920, 228.322, 200.000},
    {"Ocean Docks", 2373.770, -2697.090, -89.084, 2809.220, -2330.460, 110.916},
    {"Easter Bay Airport", -1213.910, -50.096, -4.5, -947.980, 578.396, 200.000},
    {"Whitewood Estates", 883.308, 1726.220, -89.084, 1098.310, 2507.230, 110.916},
    {"Calton Heights", -2274.170, 744.170, -6.1, -1982.320, 1358.900, 200.000},
    {"Easter Basin", -1794.920, 249.904, -9.1, -1242.980, 578.396, 200.000},
    {"Los Santos Inlet", -321.744, -2224.430, -89.084, 44.615, -1724.430, 110.916},
    {"Doherty", -2173.040, -222.589, -1.0, -1794.920, 265.243, 200.000},
    {"Mount Chiliad", -2178.690, -2189.910, -47.917, -2030.120, -1771.660, 576.083},
    {"Fort Carson", -376.233, 826.326, -3.0, 123.717, 1220.440, 200.000},
    {"Foster Valley", -2178.690, -1115.580, 0.000, -1794.920, -599.884, 200.000},
    {"Ocean Flats", -2994.490, -222.589, -1.0, -2593.440, 277.411, 200.000},
    {"Fern Ridge", 508.189, -139.259, 0.000, 1306.660, 119.526, 200.000},
    {"Bayside", -2741.070, 2175.150, 0.000, -2353.170, 2722.790, 200.000},
    {"Las Venturas Airport", 1457.370, 1203.280, -89.084, 1777.390, 1883.110, 110.916},
    {"Blueberry Acres", -319.676, -220.137, 0.000, 104.534, 293.324, 200.000},
    {"Palisades", -2994.490, 458.411, -6.1, -2741.070, 1339.610, 200.000},
    {"North Rock", 2285.370, -768.027, 0.000, 2770.590, -269.740, 200.000},
    {"Hunter Quarry", 337.244, 710.840, -115.239, 860.554, 1031.710, 203.761},
    {"Los Santos International", 1382.730, -2730.880, -89.084, 2201.820, -2394.330, 110.916},
    {"Missionary Hill", -2994.490, -811.276, 0.000, -2178.690, -430.276, 200.000},
    {"San Fierro Bay", -2616.400, 1659.680, -3.0, -1996.660, 2175.150, 200.000},
    {"Restricted Area", -91.586, 1655.050, -50.000, 421.234, 2123.010, 250.000},
    {"Mount Chiliad", -2997.470, -1115.580, -47.917, -2178.690, -971.913, 576.083},
    {"Mount Chiliad", -2178.690, -1771.660, -47.917, -1936.120, -1250.970, 576.083},
    {"Easter Bay Airport", -1794.920, -730.118, -3.0, -1213.910, -50.096, 200.000},
    {"The Panopticon", -947.980, -304.320, -1.1, -319.676, 327.071, 200.000},
    {"Shady Creeks", -1820.640, -2643.680, -8.0, -1226.780, -1771.660, 200.000},
    {"Back o Beyond", -1166.970, -2641.190, 0.000, -321.744, -1856.030, 200.000},
    {"Mount Chiliad", -2994.490, -2189.910, -47.917, -2178.690, -1115.580, 576.083},

    {"Tierra Robada", -1213.910, 596.349, -242.990, -480.539, 1659.680, 900.000},
    {"Flint County", -1213.910, -2892.970, -242.990, 44.615, -768.027, 900.000},
    {"Whetstone", -2997.470, -2892.970, -242.990, -1213.910, -1115.580, 900.000},
    {"Bone County", -480.539, 596.349, -242.990, 869.461, 2993.870, 900.000},
    {"Tierra Robada", -2997.470, 1659.680, -242.990, -480.539, 2993.870, 900.000},
    {"San Fierro", -2997.470, -1115.580, -242.990, -1213.910, 1659.680, 900.000},
    {"Las Venturas", 869.461, 596.349, -242.990, 2997.060, 2993.870, 900.000},
    {"Red County", -1213.910, -768.027, -242.990, 2997.060, 596.349, 900.000},
    {"Los Santos", 44.615, -2892.970, -242.990, 2997.060, -768.027, 900.000}
}

VEHICLES_NAMES_BY_ID = {
	[400] = "Landstalker",
	[401] = "Bravura",
	[402] = "Buffalo",
	[403] = "Linerunner",
	[404] = "Perenniel",
	[405] = "Sentinel",
	[406] = "Dumper",
	[407] = "Firetruck",
	[408] = "Trashmaster",
	[409] = "Stretch",
	[410] = "Manana",
	[411] = "Infernus",
	[412] = "Voodoo",
	[413] = "Pony",
	[414] = "Mule",
	[415] = "Cheetah",
	[416] = "Ambulance",
	[417] = "Leviathan",
	[418] = "Moonbeam",
	[419] = "Esperanto",
	[420] = "Taxi",
	[421] = "Washington",
	[422] = "Bobcat",
	[423] = "Mr Whoopee",
	[424] = "BF Injection",
	[425] = "Hunter",
	[426] = "Premier",
	[427] = "Enforcer",
	[428] = "Securicar",
	[429] = "Banshee",
	[430] = "Predator",
	[431] = "Bus",
	[432] = "Rhino",
	[433] = "Barracks",
	[434] = "Hotknife",
	[435] = "Article Trailer",
	[436] = "Previon",
	[437] = "Coach",
	[438] = "Cabbie",
	[439] = "Stallion",
	[440] = "Rumpo",
	[441] = "RC Bandit",
	[442] = "Romero",
	[443] = "Packer",
	[444] = "Monster",
	[445] = "Admiral",
	[446] = "Squallo",
	[447] = "Seasparrow",
	[448] = "Pizzaboy",
	[449] = "Tram",
	[450] = "Article Trailer 2",
	[451] = "Turismo",
	[452] = "Speeder",
	[453] = "Reefer",
	[454] = "Tropic",
	[455] = "Flatbed",
	[456] = "Yankee",
	[457] = "Caddy",
	[458] = "Solair",
	[459] = "Topfun Van (Berkley’s RC)",
	[460] = "Skimmer",
	[461] = "PCJ-600",
	[462] = "Faggio",
	[463] = "Freeway",
	[464] = "RC Baron",
	[465] = "RC Raider",
	[466] = "Glendale",
	[467] = "Oceanic",
	[468] = "Sanchez",
	[469] = "Sparrow",
	[470] = "Patriot",
	[471] = "Quad",
	[472] = "Coastguard",
	[473] = "Dinghy",
	[474] = "Hermes",
	[475] = "Sabre",
	[476] = "Rustler",
	[477] = "ZR-350",
	[478] = "Walton",
	[479] = "Regina",
	[480] = "Comet",
	[481] = "BMX",
	[482] = "Burrito",
	[483] = "Camper",
	[484] = "Marquis",
	[485] = "Baggage",
	[486] = "Dozer",
	[487] = "Maverick",
	[488] = "SAN News Maverick",
	[489] = "Rancher",
	[490] = "FBI Rancher",
	[491] = "Virgo",
	[492] = "Greenwood",
	[493] = "Jetmax",
	[494] = "Hotring Racer",
	[495] = "Sandking",
	[496] = "Blista Compact",
	[497] = "Police Maverick",
	[498] = "Boxville",
	[499] = "Benson",
	[500] = "Mesa",
	[501] = "RC Goblin",
	[502] = "Hotring Racer",
	[503] = "Hotring Racer",
	[504] = "Bloodring Banger",
	[505] = "Rancher",
	[506] = "Super GT",
	[507] = "Elegant",
	[508] = "Journey",
	[509] = "Bike",
	[510] = "Mountain Bike",
	[511] = "Beagle",
	[512] = "Cropduster",
	[513] = "Stuntplane",
	[514] = "Tanker",
	[515] = "Roadtrain",
	[516] = "Nebula",
	[517] = "Majestic",
	[518] = "Buccaneer",
	[519] = "Shamal",
	[520] = "Hydra",
	[521] = "FCR-900",
	[522] = "NRG-500",
	[523] = "HPV-1000",
	[524] = "Cement Truck",
	[525] = "Towtruck",
	[526] = "Fortune",
	[527] = "Cadrona",
	[528] = "FBI Truck",
	[529] = "Willard",
	[530] = "Forklift",
	[531] = "Tractor",
	[532] = "Combine Harvester",
	[533] = "Feltzer",
	[534] = "Remington",
	[535] = "Slamvan",
	[536] = "Blade",
	[537] = "Freight (Train)",
	[538] = "Brownstreak (Train)",
	[539] = "Vortex",
	[540] = "Vincent",
	[541] = "Bullet",
	[542] = "Clover",
	[543] = "Sadler",
	[544] = "Firetruck LA",
	[545] = "Hustler",
	[546] = "Intruder",
	[547] = "Primo",
	[548] = "Cargobob",
	[549] = "Tampa",
	[550] = "Sunrise",
	[551] = "Merit",
	[552] = "Utility Van",
	[553] = "Nevada",
	[554] = "Yosemite",
	[555] = "Windsor",
	[556] = "Monster «A»",
	[557] = "Monster «B»",
	[558] = "Uranus",
	[559] = "Jester",
	[560] = "Sultan",
	[561] = "Stratum",
	[562] = "Elegy",
	[563] = "Raindance",
	[564] = "RC Tiger",
	[565] = "Flash",
	[566] = "Tahoma",
	[567] = "Savanna",
	[568] = "Bandito",
	[569] = "Freight Flat Trailer (Train)",
	[570] = "Streak Trailer (Train)",
	[571] = "Kart",
	[572] = "Mower",
	[573] = "Dune",
	[574] = "Sweeper",
	[575] = "Broadway",
	[576] = "Tornado",
	[577] = "AT400",
	[578] = "DFT-30",
	[579] = "Huntley",
	[580] = "Stafford",
	[581] = "BF-400",
	[582] = "Newsvan",
	[583] = "Tug",
	[584] = "Petrol Trailer",
	[585] = "Emperor",
	[586] = "Wayfarer",
	[587] = "Euros",
	[588] = "Hotdog",
	[589] = "Club",
	[590] = "Freight Box Trailer (Train)",
	[591] = "Article Trailer 3",
	[592] = "Andromada",
	[593] = "Dodo",
	[594] = "RC Cam",
	[595] = "Launch",
	[596] = "Police LS",
	[597] = "Police SF",
	[598] = "Police LV",
	[599] = "Police Ranger",
	[600] = "Picador",
	[601] = "S.W.A.T.",
	[602] = "Alpha",
	[603] = "Phoenix",
	[604] = "Glendale",
	[605] = "Sadler",
	[606] = "Baggage Trailer «A»",
	[607] = "Baggage Trailer «B»",
	[608] = "Tug Stairs Trailer",
	[609] = "Boxville",
	[610] = "Farm Trailer",
	[611] = "Utility Trailer"
}