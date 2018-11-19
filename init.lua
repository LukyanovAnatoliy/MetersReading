INPUT1=0; -- GPIO16
INPUT2=5; -- GPIO14
INPUT3=6; -- GPIO12 
INPUT4=7; -- GPIO13

LED_GPIO = INPUT3; 
COLD_GPIO = INPUT1; 
HOT_GPIO = INPUT2;
POWER_GPIO = INPUT4;

node.setcpufreq(node.CPU80MHZ);

INC_VALUE = 10; -- инкрементирующее значение в литрах

TYPE_WATER_METER = "1";
TYPE_POWER_METER = "2";

PARAM_SSID = "ssid";
PARAM_PASSWORD = "password";
PARAM_API_KEY = "api_key";
PARAM_COLD_FIELD_INC = "cold_field_incr";
PARAM_COLD_FIELD_TOTAL = "cold_field_total";
PARAM_COLD_VALUE = "cold_value";
PARAM_HOT_FIELD_INC = "hot_field_incr";
PARAM_HOT_FIELD_TOTAL = "hot_field_total";
PARAM_HOT_VALUE = "hot_value";
PARAM_POWER_FIELD_INC = "power_field_incr";
PARAM_POWER_FIELD_TOTAL = "power_field_total";
PARAM_POWER_VALUE = "power_value";
PARAM_POWER_FIELD_CURRENT_CONS = "power_field_current_cons";
PARAM_POWER_FIELD_MAX_VALUE = "power_field_max_value";
PARAM_TYPE_ACCOUNTING = "type_meter";
PARAM_COUNT_IMPULS_IN_KW = "count_impuls_in_kW";

FILE_MAIN_PARAMETERS = "main_parameters";
FILE_COLD = "cold";
FILE_HOT = "hot";
FILE_POWER = "power";

settings = {};
cold_values = {};
hot_values = {};
power_values = {};

-- настройка GPIO
--gpio.mode(LED_GPIO, gpio.OUTPUT)
--gpio.mode(BUTTON_GPIO, gpio.INPUT, gpio.PULLUP);

-- настройка GPIO
gpio.mode(LED_GPIO, gpio.OUTPUT);
gpio.mode(COLD_GPIO, gpio.INPUT, gpio.PULLUP);
gpio.mode(HOT_GPIO, gpio.INPUT, gpio.PULLUP);
gpio.mode(POWER_GPIO, gpio.INPUT, gpio.PULLUP);

-- включение светодиода
function led_on()
    gpio.write(LED_GPIO, gpio.HIGH);
end;

-- отключение светодиода  
function led_off()
    gpio.write(LED_GPIO, gpio.LOW);
end;

function invert_led()
    if (gpio.read(LED_GPIO) == 1) then
        led_off();
    else
        led_on();
    end;
end;

function val_to_str ( v )
    return ((v == nil) or (v == "")) and '""' or '"'..v..'"'
end;

-- перевод таблицы в строку 
function table_to_str(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        table.insert( result, k .. "=" .. val_to_str( v ) )
    end
    return "{" .. table.concat( result, "," ) .. "}"
end;

-- сохранение таблицы в файл 
function write_to_file(fileName, tbl)
    file.open(fileName, "w+");
    file.write(table_to_str(tbl));
    file.flush();
    file.close();
end;

-- чтение данных из файла
function read_from_file(fileName)
    if (file.open(fileName, "r")) then
        str = file.read();
        file.close();
        if (str == nil) or (str == "") then
            return {};
        else
            return loadstring("return "..str)();
        end;
    else 
        return {}
    end;
end;

-- 
function showError()
    tmr.alarm(0, 500, tmr.ALARM_AUTO, function() 
            invert_led();
        end) 
end;

function setup_wifi_as_station()
    wifi.sta.clearconfig();
    -- подключаемся к wifi точке 
    wifi.setmode(wifi.STATION);
    station_cfg={}
    station_cfg.ssid=settings[PARAM_SSID]
    station_cfg.pwd=settings[PARAM_PASSWORD]
    wifi.sta.config(station_cfg);
    wifi.sta.autoconnect(1);
    wifi.sta.connect();
end;

settings = read_from_file(FILE_MAIN_PARAMETERS);
cold_values = read_from_file(FILE_COLD);
hot_values = read_from_file(FILE_HOT);
power_values = read_from_file(FILE_POWER);


-- зададим начальные значения если ничего не задано
if (cold_values.total == nil) then
    cold_values.inc = 0;
    cold_values.total = 0;
end;

if (hot_values.total == nil) then
    hot_values.inc = 0;
    hot_values.total = 0;
end;

if (power_values.total == nil) then
    power_values.inc = 0;
    power_values.total = 0;
end;

if (settings[PARAM_SSID] == nil) then
    settings[PARAM_SSID] = "";
    settings[PARAM_PASSWORD] = "";
    settings[PARAM_API_KEY] = "";
    settings[PARAM_COLD_FIELD_INC] = "";
    settings[PARAM_COLD_FIELD_TOTAL] = "";
    settings[PARAM_HOT_FIELD_INC] = "";
    settings[PARAM_HOT_FIELD_TOTAL] = "";
    settings[PARAM_POWER_FIELD_INC] = "";
    settings[PARAM_POWER_FIELD_TOTAL] = "";
    settings[PARAM_TYPE_ACCOUNTING] = TYPE_WATER_METER;
    settings[PARAM_COUNT_IMPULS_IN_KW] = "";
    settings[PARAM_POWER_FIELD_CURRENT_CONS] = "";
    settings[PARAM_POWER_FIELD_MAX_VALUE] = "";
end;

print(table_to_str(settings));

--adc.force_init_mode(adc.INIT_VDD33);

-- всегда при старте запускаем режим настройки
-- если в течение 60 секунд никто не подключился и были введены настройки точки доступа, 
-- то отключаем режим настройки и запускаем считывание показаний
dofile("setup_mode.lua");
