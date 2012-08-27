test2html is a simple tool to convert the test logs created by the gdc (gdcproject.org) test
suite to nice html pages.

## Compiling ##
There's no build script to compile test2html, so it has to be compiled manually.

test2html uses [mustache4d](https://github.com/repeatedly/mustache4d) for html templates. You
first have to compile mustache4d. Then replace "../mustache4d" with the path to your mustache4d
installation.

Use one of these commands

```
gdmd main.d parse.d config.d -I../mustache4d/src -L-L../mustache4d -L-lmustache -oftest2html
```

```
dmd main.d parse.d config.d -I../mustache4d/src -L-L../mustache4d -L-lmustache -oftest2html
```

## Usage ##
test2html requires a configuration file in json format. The output is directly written to stdout.
It's then called like this:
```
test2html --config config.json > testsuite.html
```
If *--externalCSS* is passed test2html does not embed the testsuite.css file and instead references it.

## Config file ##
The JSON config file should look like this:
```json
{
    "input" : [
        {
            "name" : "x86",
            "sum" : "input/x86.sum",
            "log" : "input/x86.log",
            "logURL" : "log/x86.log.html",
            "tooltip" : "ARCH: x86<br />Special flags: none<br />GCC: 4.7.1 FSF<br />GDC: 9bcc0b71(gdc-4.7.1)",
            "link" : "http://gdcproject.org/wiki/Test Results/x86"
        },
        {
            "name" : "x86-64",
            "sum" : "input/x86-64.sum",
            "log" : "input/x86-64.log",
            "logURL" : "log/x86-64.log.html",
            "tooltip" : "ARCH: x86-64<br />Special flags: none<br />GCC: 4.7.1 FSF<br />GDC: 9bcc0b71(gdc-4.7.1)",
            "link" : "http://gdcproject.org/wiki/Test Results/x86-64"
        }
    ]
}
```
name, sum and log are required, the rest is optional.

## TODO ##
* The code is currently quite ugly
* Could possibly use sqlite to store the data of the test runs
* Does not yet support multiple variants in a test log

## FIXME ##
* The template.mustache and the testsuite.css file are always looked up in the
  current directory. They should be looked up relative to the test2html executable
  by default and it should be possible to specify custom filenames.
