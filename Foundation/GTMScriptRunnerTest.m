//
//  GTMScriptRunnerTest.m
//
//  Copyright 2007-2008 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import <sys/types.h>
#import <unistd.h>
#import "GTMSenTestCase.h"
#import "GTMScriptRunner.h"

@interface GTMScriptRunnerTest : SenTestCase {
 @private 
  NSString *shScript_;
  NSString *perlScript_;
  NSString *shOutputScript_;
}
@end

@interface GTMScriptRunnerTest (PrivateMethods)
- (void)helperTestBourneShellUsingScriptRunner:(GTMScriptRunner *)sr;
@end

@implementation GTMScriptRunnerTest

- (void)setUp {
  shScript_ = [NSString stringWithFormat:@"/tmp/script_runner_unittest_%d_%d_sh", geteuid(), getpid()];
  [@"#!/bin/sh\n"
   @"i=1\n"
   @"if [ -n \"$1\" ]; then\n"
   @"  i=$1\n"
   @"fi\n"
   @"echo $i\n"
   writeToFile:shScript_ atomically:YES encoding:NSUTF8StringEncoding error:nil];
  
  perlScript_ = [NSString stringWithFormat:@"/tmp/script_runner_unittest_%d_%d_pl", geteuid(), getpid()];
  [@"#!/usr/bin/perl\n"
   @"use strict;\n"
   @"my $i = 1;\n"
   @"if (defined $ARGV[0]) {\n"
   @"  $i = $ARGV[0];\n"
   @"}\n"
   @"print \"$i\n\"\n"
   writeToFile:perlScript_ atomically:YES encoding:NSUTF8StringEncoding error:nil];

  shOutputScript_ = [NSString stringWithFormat:@"/tmp/script_runner_unittest_err_%d_%d_sh", geteuid(), getpid()];
  [@"#!/bin/sh\n"
   @"if [ \"err\" = \"$1\" ]; then\n"
   @"  echo \" on err \" > /dev/stderr\n"
   @"else\n"
   @"  echo \" on out \"\n"
   @"fi\n"
   writeToFile:shOutputScript_ atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)tearDown {
  const char *path = [shScript_ fileSystemRepresentation];
  if (path)
    unlink(path);
  path = [perlScript_ fileSystemRepresentation];
  if (path)
    unlink(path);
  path = [shOutputScript_ fileSystemRepresentation];
  if (path)
    unlink(path);
}

- (void)testShCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runner];
  [self helperTestBourneShellUsingScriptRunner:sr];
}

- (void)testBashCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithBash];
  [self helperTestBourneShellUsingScriptRunner:sr];
}

- (void)testZshCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithInterpreter:@"/bin/zsh"];
  [self helperTestBourneShellUsingScriptRunner:sr];
}

- (void)testBcCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithInterpreter:@"/usr/bin/bc"
                                                    withArgs:[NSArray arrayWithObject:@"-lq"]];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple expression (NOTE that bc requires that commands end with a newline)
  output = [sr run:@"1 + 2\n"];
  STAssertEqualObjects(output, @"3", @"output should equal '3'");
  
  // Simple expression with variables and multiple statements
  output = [sr run:@"i=1; i+2\n"];
  STAssertEqualObjects(output, @"3", @"output should equal '3'");
  
  // Simple expression with base conversion
  output = [sr run:@"obase=2; 2^5\n"];
  STAssertEqualObjects(output, @"100000", @"output should equal '100000'");
  
  // Simple expression with sine and cosine functions
  output = [sr run:@"scale=3;s(0)+c(0)\n"];
  STAssertEqualObjects(output, @"1.000", @"output should equal '1.000'");
}

- (void)testPerlCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithPerl];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple print
  output = [sr run:@"print 'hi'"];
  STAssertEqualObjects(output, @"hi", @"output should equal 'hi'");
  
  // Simple print x4
  output = [sr run:@"print 'A'x4"];
  STAssertEqualObjects(output, @"AAAA", @"output should equal 'AAAA'");
  
  // Simple perl-y stuff
  output = [sr run:@"my $i=0; until ($i++==41){} print $i"];
  STAssertEqualObjects(output, @"42", @"output should equal '42'");
}

- (void)testPythonCommands {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithPython];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple print
  output = [sr run:@"print 'hi'"];
  STAssertEqualObjects(output, @"hi", @"output should equal 'hi'");
  
  // Simple python expression
  output = [sr run:@"print '-'.join(['a', 'b', 'c'])"];
  STAssertEqualObjects(output, @"a-b-c", @"output should equal 'a-b-c'");
}

- (void)testBashScript {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithBash];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple sh script
  output = [sr runScript:shScript_];
  STAssertEqualObjects(output, @"1", @"output should equal '1'");
  
  // Simple sh script with 1 command line argument
  output = [sr runScript:shScript_ withArgs:[NSArray arrayWithObject:@"2"]];
  STAssertEqualObjects(output, @"2", @"output should equal '2'");
}

- (void)testPerlScript {
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithPerl];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple Perl script
  output = [sr runScript:perlScript_];
  STAssertEqualObjects(output, @"1", @"output should equal '1'");
  
  // Simple perl script with 1 command line argument
  output = [sr runScript:perlScript_ withArgs:[NSArray arrayWithObject:@"2"]];
  STAssertEqualObjects(output, @"2", @"output should equal '2'");
}

- (void)testEnvironment {
  GTMScriptRunner *sr = [GTMScriptRunner runner];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  STAssertNil([sr environment], @"should start w/ empty env");
  
  output = [sr run:@"/usr/bin/env | wc -l"];
  int numVars = [output intValue];
  STAssertTrue(numVars > 0, @"numVars should be positive");
  // By default the environment is wiped clean, however shells often add a few
  // of their own env vars after things have been wiped. For example, sh will 
  // add about 3 env vars (PWD, _, and SHLVL).
  STAssertTrue(numVars < 5, @"Our env should be almost empty");
  
  NSDictionary *newEnv = [NSDictionary dictionaryWithObject:@"bar"
                                                     forKey:@"foo"];
  [sr setEnvironment:newEnv];
  
  output = [sr run:@"/usr/bin/env | wc -l"];
  STAssertTrue([output intValue] == numVars + 1,
               @"should have one more env var now");
  
  [sr setEnvironment:nil];
  output = [sr run:@"/usr/bin/env | wc -l"];
  STAssertTrue([output intValue] == numVars,
               @"should be back down to %d vars", numVars);
  
  NSDictionary *currVars = [[NSProcessInfo processInfo] environment];
  [sr setEnvironment:currVars];
  
  output = [sr run:@"/usr/bin/env | wc -l"];
  STAssertTrue([output intValue] == [currVars count],
               @"should be back down to %d vars", numVars);
}

- (void)testDescription {
  // make sure description doesn't choke
  GTMScriptRunner *sr = [GTMScriptRunner runner];
  STAssertNotNil(sr, @"Script runner must not be nil");
  STAssertGreaterThan([[sr description] length], (NSUInteger)10,
                      @"expected a description of at least 10 chars");
}

- (void)testRunCommandOutputHandling {
  // Test whitespace trimming & stdout vs. stderr w/ run command api
  
  GTMScriptRunner *sr = [GTMScriptRunner runnerWithBash];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  NSString *err = nil;
  
  // w/o whitespace trimming
  {
    [sr setTrimsWhitespace:NO];
    STAssertFalse([sr trimsWhitespace], @"setTrimsWhitespace to NO failed");
    
    // test stdout
    output = [sr run:@"echo \" on out \"" standardError:&err];
    STAssertEqualObjects(output, @" on out \n", @"failed to get stdout output");
    STAssertNil(err, @"stderr should have been empty");
    
    // test stderr
    output = [sr run:@"echo \" on err \" > /dev/stderr" standardError:&err];
    STAssertNil(output, @"stdout should have been empty");
    STAssertEqualObjects(err, @" on err \n", nil);
  }
  
  // w/ whitespace trimming
  {
    [sr setTrimsWhitespace:YES];
    STAssertTrue([sr trimsWhitespace], @"setTrimsWhitespace to YES failed");
    
    // test stdout
    output = [sr run:@"echo \" on out \"" standardError:&err];
    STAssertEqualObjects(output, @"on out", @"failed to get stdout output");
    STAssertNil(err, @"stderr should have been empty");
    
    // test stderr
    output = [sr run:@"echo \" on err \" > /dev/stderr" standardError:&err];
    STAssertNil(output, @"stdout should have been empty");
    STAssertEqualObjects(err, @"on err", nil);
  }
}

- (void)testScriptOutputHandling {
  // Test whitespace trimming & stdout vs. stderr w/ script api

  GTMScriptRunner *sr = [GTMScriptRunner runner];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  NSString *err = nil;

  // w/o whitespace trimming
  {
    [sr setTrimsWhitespace:NO];
    STAssertFalse([sr trimsWhitespace], @"setTrimsWhitespace to NO failed");
  
    // test stdout
    output = [sr runScript:shOutputScript_
                  withArgs:[NSArray arrayWithObject:@"out"]
             standardError:&err];
    STAssertEqualObjects(output, @" on out \n", nil);
    STAssertNil(err, @"stderr should have been empty");
    
    // test stderr
    output = [sr runScript:shOutputScript_
                  withArgs:[NSArray arrayWithObject:@"err"]
             standardError:&err];
    STAssertNil(output, @"stdout should have been empty");
    STAssertEqualObjects(err, @" on err \n", nil);
  }
  
  // w/ whitespace trimming
  {
    [sr setTrimsWhitespace:YES];
    STAssertTrue([sr trimsWhitespace], @"setTrimsWhitespace to YES failed");
    
    // test stdout
    output = [sr runScript:shOutputScript_
                  withArgs:[NSArray arrayWithObject:@"out"]
             standardError:&err];
    STAssertEqualObjects(output, @"on out", nil);
    STAssertNil(err, @"stderr should have been empty");
    
    // test stderr
    output = [sr runScript:shOutputScript_
                  withArgs:[NSArray arrayWithObject:@"err"]
             standardError:&err];
    STAssertNil(output, @"stdout should have been empty");
    STAssertEqualObjects(err, @"on err", nil);
  }
}

- (void)testBadRunCommandInput {
  GTMScriptRunner *sr = [GTMScriptRunner runner];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *err = nil;
  
  STAssertNil([sr run:nil standardError:&err], nil);
  STAssertNil(err, nil);
}

- (void)testBadScriptInput {
  GTMScriptRunner *sr = [GTMScriptRunner runner];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *err = nil;
  
  STAssertNil([sr runScript:nil withArgs:nil standardError:&err], nil);
  STAssertNil(err, nil);
  STAssertNil([sr runScript:@"/path/that/does/not/exists/foo/bar/baz"
                   withArgs:nil standardError:&err], nil);
  STAssertNotNil(err,
                 @"should have gotten something about the path not existing");
}

- (void)testBadCmdInterpreter {
  GTMScriptRunner *sr =
    [GTMScriptRunner runnerWithInterpreter:@"/path/that/does/not/exists/interpreter"];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *err = nil;
  
  STAssertNil([sr run:nil standardError:&err], nil);
  STAssertNil(err, nil);
  STAssertNil([sr run:@"ls /" standardError:&err], nil);
  STAssertNil(err, nil);
}

- (void)testBadScriptInterpreter {
  GTMScriptRunner *sr =
    [GTMScriptRunner runnerWithInterpreter:@"/path/that/does/not/exists/interpreter"];
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *err = nil;
  
  STAssertNil([sr runScript:shScript_ withArgs:nil standardError:&err], nil);
  STAssertNil(err, nil);
  STAssertNil([sr runScript:@"/path/that/does/not/exists/foo/bar/baz"
                   withArgs:nil standardError:&err], nil);
  STAssertNil(err, nil);
}


@end

@implementation GTMScriptRunnerTest (PrivateMethods)

- (void)helperTestBourneShellUsingScriptRunner:(GTMScriptRunner *)sr {
  STAssertNotNil(sr, @"Script runner must not be nil");
  NSString *output = nil;
  
  // Simple command
  output = [sr run:@"ls /etc/passwd"];
  STAssertEqualObjects(output, @"/etc/passwd", @"output should equal '/etc/passwd'");
  
  // Simple command pipe-line
  output = [sr run:@"ls /etc/ | grep passwd | tail -1"];
  STAssertEqualObjects(output, @"passwd", @"output should equal 'passwd'");
  
  // Simple pipe-line with quotes and awk variables
  output = [sr run:@"ps jaxww | awk '{print $2}' | sort -nr | tail -2 | head -1"];
  STAssertEqualObjects(output, @"1", @"output should equal '1'");
  
  // Simple shell loop with variables
  output = [sr run:@"i=0; while [ $i -lt 100 ]; do i=$((i+1)); done; echo $i"];
  STAssertEqualObjects(output, @"100", @"output should equal '100'");
  
  // Simple command with newlines
  output = [sr run:@"i=1\necho $i"];
  STAssertEqualObjects(output, @"1", @"output should equal '1'");
  
  // Simple full shell script
  output = [sr run:@"#!/bin/sh\ni=1\necho $i\n"];
  STAssertEqualObjects(output, @"1", @"output should equal '1'");
  
  NSString *err = nil;
  
  // Test getting standard error with no stdout
  output = [sr run:@"ls /etc/does-not-exist" standardError:&err];
  STAssertNil(output, @"output should be nil due to expected error");
  STAssertEqualObjects(err, @"ls: /etc/does-not-exist: No such file or directory", @"");
  
  // Test getting standard output along with some standard error
  output = [sr run:@"ls /etc/does-not-exist /etc/passwd" standardError:&err];
  STAssertEqualObjects(output, @"/etc/passwd", @"");
  STAssertEqualObjects(err, @"ls: /etc/does-not-exist: No such file or directory", @"");
}

@end
