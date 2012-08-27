module parse;

import std.string;
import std.array;
import std.algorithm;
import std.stdio;

enum Status
{
    fail,
    pass,
    unresolved
}

struct TestEntry
{
    Status status;
    string file;
    string info;
}

struct Test
{
    TestEntry[] entries;
    Status status;
}

struct TestSection
{
    string name;
    Test[] tests;
    size_t passed;
    size_t numTests;
    size_t failed;
    size_t unresolved;
}

struct TestRun
{
    string name;
    TestHash tests;
    size_t passed;
    size_t numTests;
    size_t failed;
    size_t unresolved;
    Test[string] allTests;
    //TODO: Sub-TestRuns (e.g -fno-section-anchors, etc)
}

alias TestSection[string] TestHash;


Status overallStatus(Test test)
{
    Status stat = Status.pass;
    foreach(entry; test.entries)
    {
        if(entry.status == Status.fail && stat != Status.unresolved)
            stat = Status.fail;
        else if(entry.status == Status.unresolved)
            stat = Status.unresolved;
    }
    return stat;
}

TestRun analyzeTestRun(string name, string fileName)
{
    TestRun run;
    run.name = name;
    
    auto file = File(fileName);
    foreach(line; file.byLine)
    {
        TestEntry t;
        if(line.startsWith("FAIL:"))
        {
            t.status = Status.fail;
            fillName(line, t);
            if(!(t.file in run.allTests))
                run.allTests[t.file] = Test.init;
            run.allTests[t.file].entries ~= t;
        }
        else if(line.startsWith("PASS:"))
        {
            t.status = Status.pass;
            fillName(line, t);
            if(!(t.file in run.allTests))
                run.allTests[t.file] = Test.init;
            run.allTests[t.file].entries ~= t;
        }
        else if(line.startsWith("UNRESOLVED:"))
        {
            t.status = Status.unresolved;
            fillName(line, t);
            if(!(t.file in run.allTests))
                run.allTests[t.file] = Test.init;
            run.allTests[t.file].entries ~= t;
        }
    }
    
    foreach(key, ref val; run.allTests)
    {
        val.status = overallStatus(val);
        final switch(val.status)
        {
            case Status.pass:
                 run.passed++;
                 break;
            case Status.fail:
                 run.failed++;
                 break;
            case Status.unresolved:
                 run.unresolved++;
                 break;
        }
        run.numTests++;
    }
    
    auto sectionTests = splitTests(run.allTests.keys);
    
    foreach(sectionName, tests; sectionTests)
    {
        TestSection sect;
        sect.name = sectionName;
        foreach(test; tests)
        {
            if(test in run.allTests)
            {
                sect.tests ~= run.allTests[test];
                final switch(run.allTests[test].status)
                {
                    case Status.pass:
                         sect.passed++;
                         break;
                    case Status.fail:
                         sect.failed++;
                         break;
                    case Status.unresolved:
                         sect.unresolved++;
                         break;
                }
                sect.numTests++;
            }
        }
        run.tests[sect.name] = sect;
    }
    return run;
}

void fillName(const(char)[] line, ref TestEntry test)
{
    auto rest = findSplit(line, ": ")[2];
    auto res = findSplit(rest, " ");
    test.file = res[0].idup;
    test.info = res[2].idup;
}

string[][string] splitTests(string[] tests)
{
    string[][string] result;
    foreach(key; tests)
    {
        auto category = findSplit(key, "/")[0];
        result[category] ~= key;
    }
    return result;
}

size_t[string] analyzeLog(string logFile)
{
    size_t[string] result;
    auto file = File(logFile);
    size_t last = 1, current = 1;
    foreach(line; file.byLine)
    {
        if(line.startsWith("FAIL:") || line.startsWith("PASS:") || line.startsWith("UNRESOLVED:"))
        {
            auto rest = findSplit(line, ": ")[2];
            auto res = findSplit(rest, " ");
            auto name = res[0].idup;
            if(!(name in result))
                result[name] = last;
            last = current + 1;
        }
        current++;
    }
    return result;
}
