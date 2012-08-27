module config;

import std.file;
import std.json;
import std.exception;

struct Config
{
    TestConfig[] tests;
}

struct TestConfig
{
    string name;
    string sumFile;
    string logFile;
    string logURL;
    string tooltip;
    string link;
}

Config loadConfig(string path)
{
    Config conf;
    
    auto root = parseJSON(readText(path));
    enforce(root.type == JSON_TYPE.OBJECT && "input" in root.object);
    auto inp = root.object["input"];
    enforce(inp.type == JSON_TYPE.ARRAY);
    foreach(val; inp.array)
    {
        conf.tests ~= loadTestConfig(val);
    }
    
    return conf;
}

private TestConfig loadTestConfig(JSONValue val)
{
    TestConfig conf;

    enforce(val.type == JSON_TYPE.OBJECT);
    if(auto entry = "name" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.name = entry.str;
    }
    if(auto entry = "sum" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.sumFile = entry.str;
    }
    if(auto entry = "log" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.logFile = entry.str;
    }
    if(auto entry = "logURL" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.logURL = entry.str;
    }
    if(auto entry = "tooltip" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.tooltip = entry.str;
    }
    if(auto entry = "link" in val.object)
    {
        enforce(entry.type == JSON_TYPE.STRING);
        conf.link = entry.str;
    }
    
    return conf;
}