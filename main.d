module main;

import mustache;

import std.algorithm;
import std.string;
import std.array;
import std.stdio;
import std.getopt;
import std.file : readText;
import std.conv : to;
import std.exception;
import std.path;
import std.file;

import parse;
import config;

alias MustacheEngine!(string) Mustache;
alias size_t[string] LineMap;
LineMap[TestRun] logMaps;

TestConfig[TestRun] configs;


void main(string[] args)
{
    bool externalCSS = false;
    string confFile;
    getopt(args,
           "externalCSS", &externalCSS,
           "config", &confFile);
    enforce(confFile, "--config must be used");
    auto config = loadConfig(confFile);

    TestRun[] runs;
    foreach(entry; config.tests)
    {
        auto run = analyzeTestRun(entry.name, entry.sumFile);
        configs[run] = entry;
        runs ~= run;
        
        if(exists(entry.logFile))
        {
            log2html(entry.logFile);
            logMaps[run] = analyzeLog(entry.logFile);
        }
    }
    
    string[] allTests;
    foreach(run; runs)
    {
        string[] tests = run.allTests.keys;
        sort!"a < b"(tests);
        allTests = setUnion(allTests, tests).uniq.array;
    }
    
    auto split = splitTests(allTests);
    
    Mustache mustache;
    auto context = new Mustache.Context();
    context["title"] = "Gdc test suite results";

    if(externalCSS)
    {
        auto sub = context.addSubContext("externStyleSheet");
        sub["url"] = "testsuite.css";
    }
    else
    {
        auto sub = context.addSubContext("inlineStyleSheet");
        sub["css"] = readText("testsuite.css");
    }

    generateSummary(context, runs, split);

    foreach(key, value; split)
    {
        auto sub = context.addSubContext("detailBlock");
        sub["title"] = key;
        generateDetail(sub, value, runs);
    }
    write(mustache.render("template", context));
}

void generateDetail(Mustache.Context ctx, string[] keys, TestRun[] runs)
{
    foreach(run; runs)
    {
        auto head = ctx.addSubContext("header");
        head["name"] = run.name;
        head["tooltip"] = configs[run].tooltip;
        head["link"] = configs[run].link;
    }
    
    foreach(key; keys)
    {
        auto row = ctx.addSubContext("row");
        row["name"] = key;

        foreach(run; runs)
        {
            Status overallStatus = Status.pass;
            string tooltip;
            
            if(key in run.allTests)
            {
                auto col = row.addSubContext("column");

                foreach(test; run.allTests[key].entries)
                {
                    if(tooltip && test.info)
                        tooltip ~= "<br/>";
                    tooltip ~= xformat("%s: %s", test.status, test.info);
                }
                col["value"] = to!string(run.allTests[key].status);
                if(run in logMaps && key in logMaps[run])
                {
                    col["link"] = xformat("%s#line%s", configs[run].logURL, logMaps[run][key]);
                }
                col["tooltip"] = tooltip;
            }
            else
            {
                auto col = row.addSubContext("nrColumn");
            }
        }
    }
}

void generateSummary(Mustache.Context ctx, TestRun[] runs, string[][string] split)
{
    void writeBlock(string title, scope string delegate(Status stat, TestRun run) getVal)
    {
        auto sum = ctx.addSubContext("summaryBlock");
        sum["title"] = title;
        
        sum.addSubContext("header"); //empty cell
        foreach(run; runs)
        {
            auto header = sum.addSubContext("header");
            header["name"] = run.name;
            header["tooltip"] = configs[run].tooltip;
            header["link"] = configs[run].link;
        }
        
        auto row = sum.addSubContext("row");
        auto col = row.addSubContext("column");
        col["value"] = "Passed tests";

        foreach(run; runs)
        {
            col = row.addSubContext("column");
            col["value"] = getVal(Status.pass, run);
        }

        row = sum.addSubContext("row");
        col = row.addSubContext("column");
        col["value"] = "Failed tests";
     
        foreach(run; runs)
        {
            col = row.addSubContext("column");
            col["value"] = getVal(Status.fail, run);
        }

        row = sum.addSubContext("row");
        col = row.addSubContext("column");
        col["value"] = "Unresolved tests";

        foreach(run; runs)
        {
            col = row.addSubContext("column");
            col["value"] = getVal(Status.unresolved, run);
        }
    }
    
    string getTotalValue(Status stat, TestRun run)
    {
        final switch(stat)
        {
            case Status.pass:
                return xformat("%s/%s [%0.f%%]", run.passed, run.numTests,
                ((cast(double)run.passed)/run.numTests) *100.0f);
                break;
            case Status.fail:
                return xformat("%s/%s [%0.f%%]", run.failed, run.numTests,
                ((cast(double)run.failed)/run.numTests) *100.0f);
                break;
            case Status.unresolved:
                return xformat("%s/%s [%0.f%%]", run.unresolved, run.numTests,
                ((cast(double)run.unresolved)/run.numTests) *100.0f);
                break;
        }
    }
    
    writeBlock("Overall results", &getTotalValue);
    
    foreach(key, value; split)
    {
        string getValue(Status stat, TestRun run)
        {
            if(key in run.tests)
            {
                final switch(stat)
                {
                    case Status.pass:
                        return xformat("%s/%s [%0.f%%]", run.tests[key].passed, run.tests[key].numTests,
                        ((cast(double)run.tests[key].passed)/run.tests[key].numTests) *100.0f);
                        break;
                    case Status.fail:
                        return xformat("%s/%s [%0.f%%]", run.tests[key].failed, run.tests[key].numTests,
                        ((cast(double)run.tests[key].failed)/run.tests[key].numTests) *100.0f);
                        break;
                    case Status.unresolved:
                        return xformat("%s/%s [%0.f%%]", run.tests[key].unresolved, run.tests[key].numTests,
                        ((cast(double)run.tests[key].unresolved)/run.tests[key].numTests) *100.0f);
                        break;
                }
            }
            return "";
        }
        writeBlock(key, &getValue);
    }
}

void log2html(string logFile)
{
    auto file = File(logFile);
    auto outFile = File("log" ~ dirSeparator ~ baseName(logFile) ~ ".html", "w");
    Mustache mustache;
    auto context = new Mustache.Context();

    outFile.writefln("<!DOCTYPE html>\n"
        "<html>\n"
        "  <head>\n"
        "    <meta http-equiv=\"Content-type\" content=\"text/html;charset=UTF-8\">\n"
        "    <title>%s</title>\n"
        "  </head>\n"
        "  <body>", baseName(logFile));
    
    size_t i;
    foreach(line; file.byLine)
    {
        i++;
        auto anchor = xformat("<a name=\"line%s\"></a>", i);
        auto parts = findSplit(line, ":");
        if(parts[0] == "PASS")
        {
            string colorStr = "<span style=\"color: #009900\">PASS:</span>";
            outFile.writefln("%s%s%s<br/>", anchor, colorStr, chomp(parts[2]));
        }
        else if(parts[0] == "FAIL")
        {
            string colorStr = "<span style=\"color: #CC0000\">FAIL:</span>";
            outFile.writefln("%s%s%s<br/>", anchor, colorStr, chomp(parts[2]));
        }
        else if(parts[0] == "UNRESOLVED")
        {
            string colorStr = "<span style=\"color: #CCCC00\">UNRESOLVED:</span>";
            outFile.writefln("%s%s%s<br/>", anchor, colorStr, chomp(parts[2]));
        }
        else
        {
            outFile.writefln("%s%s<br/>", anchor, chomp(line));
        }
    }
    outFile.writeln("  </body>\n"
        "</html>");
}