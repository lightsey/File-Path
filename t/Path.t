#! /usr/bin/env perl
# Path.t -- tests for module File::Path

use strict;

use Test::More tests => 168;
use Config;
use Fcntl ':mode';

BEGIN {
    # 1
    use_ok('Cwd');
    # 2
    use_ok('File::Path', qw(rmtree mkpath make_path remove_tree));
    # 3
    use_ok('File::Spec::Functions');
}

eval "use Test::Output";
my $has_Test_Output = $@ ? 0 : 1;

my $Is_VMS = $^O eq 'VMS';

# first check for stupid permissions second for full, so we clean up
# behind ourselves
for my $perm (0111,0777) {
    my $path = catdir(curdir(), "mhx", "bar");
    mkpath($path);
    chmod $perm, "mhx", $path;

    my $oct = sprintf('0%o', $perm);
    # 4
    ok(-d "mhx", "mkdir parent dir $oct");
    # 5
    ok(-d $path, "mkdir child dir $oct");

    rmtree("mhx");
    # 6
    ok(! -e "mhx", "mhx does not exist $oct");
}

# find a place to work
my ($error, $list, $file, $message);
my $tmp_base = catdir(
    curdir(),
    sprintf( 'test-%x-%x-%x', time, $$, rand(99999) ),
);

# invent some names
my @dir = (
    catdir($tmp_base, qw(a b)),
    catdir($tmp_base, qw(a c)),
    catdir($tmp_base, qw(z b)),
    catdir($tmp_base, qw(z c)),
);

# create them
my @created = mkpath([@dir]);

# 7
is(scalar(@created), 7, "created list of directories");

# pray for no race conditions blowing them out from under us
@created = mkpath([$tmp_base]);
is(scalar(@created), 0, "skipped making existing directory")
    or diag("unexpectedly recreated @created");

# create a file
my $file_name = catfile( $tmp_base, 'a', 'delete.me' );
my $file_count = 0;
if (open OUT, "> $file_name") {
    print OUT "this file may be deleted\n";
    close OUT;
    ++$file_count;
}
else {
    diag( "Failed to create file $file_name: $!" );
}

SKIP: {
    skip "cannot remove a file we failed to create", 1
        unless $file_count == 1;
    my $count = rmtree($file_name);
# 8
    is($count, 1, "rmtree'ed a file");
}

@created = mkpath('');
# 9
is(scalar(@created), 0, "Can't create a directory named ''");

my $dir;
my $dir2;

sub gisle {
    # background info: @_ = 1; !shift # gives '' not 0
    # Message-Id: <3C820CE6-4400-4E91-AF43-A3D19B356E68@activestate.com>
    # http://www.nntp.perl.org/group/perl.perl5.porters/2008/05/msg136625.html
    mkpath(shift, !shift, 0755);
}

sub count {
    opendir D, shift or return -1;
    my $count = () = readdir D;
    closedir D or return -1;
    return $count;
}

{
    mkdir 'solo', 0755;
    chdir 'solo';
    open my $f, '>', 'foo.dat';
    close $f;
    my $before = count(curdir());
# 10
    cmp_ok($before, '>', 0, "baseline $before");

    gisle('1st', 1);
# 11
    is(count(curdir()), $before + 1, "first after $before");

    $before = count(curdir());
    gisle('2nd', 1);
# 12
    is(count(curdir()), $before + 1, "second after $before");

    chdir updir();
    rmtree 'solo';
}

{
    mkdir 'solo', 0755;
    chdir 'solo';
    open my $f, '>', 'foo.dat';
    close $f;
    my $before = count(curdir());
# 13
    cmp_ok($before, '>', 0, "ARGV $before");
    {
        local @ARGV = (1);
        mkpath('3rd', !shift, 0755);
    }
# 14
    is(count(curdir()), $before + 1, "third after $before");

    $before = count(curdir());
    {
        local @ARGV = (1);
        mkpath('4th', !shift, 0755);
    }
# 15
    is(count(curdir()), $before + 1, "fourth after $before");

    chdir updir();
    rmtree 'solo';
}

SKIP: {
    # tests for rmtree() of ancestor directory
    my $nr_tests = 6;
    my $cwd = getcwd() or skip "failed to getcwd: $!", $nr_tests;
    my $dir  = catdir($cwd, 'remove');
    my $dir2 = catdir($cwd, 'remove', 'this', 'dir');

    skip "failed to mkpath '$dir2': $!", $nr_tests
        unless mkpath($dir2, {verbose => 0});
    skip "failed to chdir dir '$dir2': $!", $nr_tests
        unless chdir($dir2);

    rmtree($dir, {error => \$error});
    my $nr_err = @$error;
# 16
    is($nr_err, 1, "ancestor error");

    if ($nr_err) {
        my ($file, $message) = each %{$error->[0]};
# 17
        is($file, $dir, "ancestor named");
        my $ortho_dir = $^O eq 'MSWin32' ? File::Path::_slash_lc($dir2) : $dir2;
        $^O eq 'MSWin32' and $message
            =~ s/\A(cannot remove path when cwd is )(.*)\Z/$1 . File::Path::_slash_lc($2)/e;
# 18
        is($message, "cannot remove path when cwd is $ortho_dir", "ancestor reason");
# 19
        ok(-d $dir2, "child not removed");
# 20
        ok(-d $dir, "ancestor not removed");
    }
    else {
        fail( "ancestor 1");
        fail( "ancestor 2");
        fail( "ancestor 3");
        fail( "ancestor 4");
    }
    chdir $cwd;
    rmtree($dir);
# 21
    ok(!(-d $dir), "ancestor now removed");
};

my $count = rmtree({error => \$error});
# 22
is( $count, 0, 'rmtree of nothing, count of zero' );
# 23
is( scalar(@$error), 0, 'no diagnostic captured' );

@created = mkpath($tmp_base, 0);
# 24
is(scalar(@created), 0, "skipped making existing directories (old style 1)")
    or diag("unexpectedly recreated @created");

$dir = catdir($tmp_base,'C');
# mkpath returns unix syntax filespecs on VMS
$dir = VMS::Filespec::unixify($dir) if $Is_VMS;
@created = make_path($tmp_base, $dir);
# 25
is(scalar(@created), 1, "created directory (new style 1)");
# 26
is($created[0], $dir, "created directory (new style 1) cross-check");

@created = mkpath($tmp_base, 0, 0700);
# 27
is(scalar(@created), 0, "skipped making existing directories (old style 2)")
    or diag("unexpectedly recreated @created");

$dir2 = catdir($tmp_base,'D');
# mkpath returns unix syntax filespecs on VMS
$dir2 = VMS::Filespec::unixify($dir2) if $Is_VMS;
@created = make_path($tmp_base, $dir, $dir2);
# 28
is(scalar(@created), 1, "created directory (new style 2)");
# 29
is($created[0], $dir2, "created directory (new style 2) cross-check");

$count = rmtree($dir, 0);
# 30
is($count, 1, "removed directory unsafe mode");

$count = rmtree($dir2, 0, 1);
my $removed = $Is_VMS ? 0 : 1;
# 31
is($count, $removed, "removed directory safe mode");

# mkdir foo ./E/../Y
# Y should exist
# existence of E is neither here nor there
$dir = catdir($tmp_base, 'E', updir(), 'Y');
@created =mkpath($dir);
# 32
cmp_ok(scalar(@created), '>=', 1, "made one or more dirs because of ..");
# 33
cmp_ok(scalar(@created), '<=', 2, "made less than two dirs because of ..");
# 34
ok( -d catdir($tmp_base, 'Y'), "directory after parent" );

@created = make_path(catdir(curdir(), $tmp_base));
# 35
is(scalar(@created), 0, "nothing created")
    or diag(@created);

$dir  = catdir($tmp_base, 'a');
$dir2 = catdir($tmp_base, 'z');

rmtree( $dir, $dir2,
    {
        error     => \$error,
        result    => \$list,
        keep_root => 1,
    }
);

# 36
is(scalar(@$error), 0, "no errors unlinking a and z");
# 37
is(scalar(@$list),  4, "list contains 4 elements")
    or diag("@$list");
# 38
ok(-d $dir,  "dir a still exists");
# 39
ok(-d $dir2, "dir z still exists");

$dir = catdir($tmp_base,'F');
# mkpath returns unix syntax filespecs on VMS
$dir = VMS::Filespec::unixify($dir) if $Is_VMS;

@created = mkpath($dir, undef, 0770);
# 40
is(scalar(@created), 1, "created directory (old style 2 verbose undef)");
# 41
is($created[0], $dir, "created directory (old style 2 verbose undef) cross-check");
# 42
is(rmtree($dir, undef, 0), 1, "removed directory 2 verbose undef");

@created = mkpath($dir, undef);
# 43
is(scalar(@created), 1, "created directory (old style 2a verbose undef)");
# 44
is($created[0], $dir, "created directory (old style 2a verbose undef) cross-check");
# 45
is(rmtree($dir, undef), 1, "removed directory 2a verbose undef");

@created = mkpath($dir, 0, undef);
# 46
is(scalar(@created), 1, "created directory (old style 3 mode undef)");
# 47
is($created[0], $dir, "created directory (old style 3 mode undef) cross-check");
# 48
is(rmtree($dir, 0, undef), 1, "removed directory 3 verbose undef");

$dir = catdir($tmp_base,'G');
$dir = VMS::Filespec::unixify($dir) if $Is_VMS;

@created = mkpath($dir, undef, 0200);
# 49
is(scalar(@created), 1, "created write-only dir");
# 50
is($created[0], $dir, "created write-only directory cross-check");
# 51
is(rmtree($dir), 1, "removed write-only dir");

# borderline new-style heuristics
if (chdir $tmp_base) {
    pass("chdir to temp dir");
}
else {
    fail("chdir to temp dir: $!");
}

$dir   = catdir('a', 'd1');
$dir2  = catdir('a', 'd2');

@created = make_path( $dir, 0, $dir2 );
# 52
is(scalar @created, 3, 'new-style 3 dirs created');

$count = remove_tree( $dir, 0, $dir2, );
# 53
is($count, 3, 'new-style 3 dirs removed');

@created = make_path( $dir, $dir2, 1 );
# 54
is(scalar @created, 3, 'new-style 3 dirs created (redux)');

$count = remove_tree( $dir, $dir2, 1 );
# 55
is($count, 3, 'new-style 3 dirs removed (redux)');

@created = make_path( $dir, $dir2 );
# 56
is(scalar @created, 2, 'new-style 2 dirs created');

$count = remove_tree( $dir, $dir2 );
# 57
is($count, 2, 'new-style 2 dirs removed');

$dir = catdir("a\nb", 'd1');
$dir2 = catdir("a\nb", 'd2');



SKIP: {
  # Better to search for *nix derivatives?
  # Not sure what else doesn't support newline in paths
  skip "This is a MSWin32 platform", 2
    if $^O eq 'MSWin32';

  @created = make_path( $dir, $dir2 );
# 58
  is(scalar @created, 3, 'new-style 3 dirs created in parent with newline');

  $count = remove_tree( $dir, $dir2 );
# 59
  is($count, 2, 'new-style 2 dirs removed in parent with newline');
}

if (chdir updir()) {
    pass("chdir parent");
}
else {
    fail("chdir parent: $!");
}

SKIP: {
    skip "This is not a MSWin32 platform", 3
        unless $^O eq 'MSWin32';

    my $UNC_path = catdir(getcwd(), $tmp_base, 'uncdir');
    #dont compute a SMB path with $ENV{COMPUTERNAME}, since SMB may be turned off
    #firewalled, disabled, blocked, or no NICs are on and there the PC has no
    #working TCPIP stack, \\?\ will always work
    $UNC_path = '\\\\?\\'.$UNC_path;
# 60
    is(mkpath($UNC_path), 1, 'mkpath on Win32 UNC path returns made 1 dir');
# 61
    ok(-d $UNC_path, 'mkpath on Win32 UNC path made dir');

    my $removed = rmtree($UNC_path);
# 62
    cmp_ok($removed, '>', 0, "removed $removed entries from $UNC_path");
}

SKIP: {
    # test bug http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=487319
    skip "Don't need Force_Writeable semantics on $^O", 6
        if grep {$^O eq $_} qw(amigaos dos epoc MSWin32 MacOS os2);
    skip "Symlinks not available", 6 unless $Config{d_symlink};
    $dir  = 'bug487319';
    $dir2 = 'bug487319-symlink';
    @created = make_path($dir, {mask => 0700});
# 63
    is( scalar @created, 1, 'bug 487319 setup' );
    symlink($dir, $dir2);
# 64
    ok(-e $dir2, "debian bug 487319 setup symlink") or diag($dir2);

    chmod 0500, $dir;
    my $mask_initial = (stat $dir)[2];
    remove_tree($dir2);

    my $mask = (stat $dir)[2];
# 65
    is( $mask, $mask_initial, 'mask of symlink target dir unchanged (debian bug 487319)');

    # now try a file
    #my $file = catfile($dir, 'file');
    my $file  = 'bug487319-file';
    my $file2 = 'bug487319-file-symlink';
    open my $out, '>', $file;
    close $out;
# 66
    ok(-e $file, 'file exists');

    chmod 0500, $file;
    $mask_initial = (stat $file)[2];

    symlink($file, $file2);
# 67
    ok(-e $file2, 'file2 exists');
    remove_tree($file2);

    $mask = (stat $file)[2];
# 68
    is( $mask, $mask_initial, 'mask of symlink target file unchanged (debian bug 487319)');

    remove_tree($dir);
    remove_tree($file);
}

# see what happens if a file exists where we want a directory
SKIP: {
    my $entry = catfile($tmp_base, "file");
    skip "VMS can have a file and a directory with the same name.", 4
        if $Is_VMS;
    skip "Cannot create $entry", 4 unless open OUT, "> $entry";
    print OUT "test file, safe to delete\n", scalar(localtime), "\n";
    close OUT;
    ok(-e $entry, "file exists in place of directory");

    mkpath( $entry, {error => \$error} );
    is( scalar(@$error), 1, "caught error condition" );
    ($file, $message) = each %{$error->[0]};
    is( $entry, $file, "and the message is: $message");

    eval {@created = mkpath($entry, 0, 0700)};
    $error = $@;
    chomp $error; # just to remove silly # in TAP output
    cmp_ok( $error, 'ne', "", "no directory created (old-style) err=$error" )
        or diag(@created);
}

my $extra =  catdir(curdir(), qw(EXTRA 1 a));

SKIP: {
    skip "extra scenarios not set up, see eg/setup-extra-tests", 14
        unless -e $extra;
    skip "Symlinks not available", 14 unless $Config{d_symlink};

    my ($list, $err);
    $dir = catdir( 'EXTRA', '1' );
    rmtree( $dir, {result => \$list, error => \$err} );
    is(scalar(@$list), 2, "extra dir $dir removed");
    is(scalar(@$err), 1, "one error encountered");

    $dir = catdir( 'EXTRA', '3', 'N' );
    rmtree( $dir, {result => \$list, error => \$err} );
    is( @$list, 1, q{remove a symlinked dir} );
    is( @$err,  0, q{with no errors} );

    $dir = catdir('EXTRA', '3', 'S');
    rmtree($dir, {error => \$error});
    is( scalar(@$error), 1, 'one error for an unreadable dir' );
    eval { ($file, $message) = each %{$error->[0]}};
    is( $file, $dir, 'unreadable dir reported in error' )
        or diag($message);

    $dir = catdir('EXTRA', '3', 'T');
    rmtree($dir, {error => \$error});
    is( scalar(@$error), 1, 'one error for an unreadable dir T' );
    eval { ($file, $message) = each %{$error->[0]}};
    is( $file, $dir, 'unreadable dir reported in error T' );

    $dir = catdir( 'EXTRA', '4' );
    rmtree($dir,  {result => \$list, error => \$err} );
    is( scalar(@$list), 0, q{don't follow a symlinked dir} );
    is( scalar(@$err),  2, q{two errors when removing a symlink in r/o dir} );
    eval { ($file, $message) = each %{$err->[0]} };
    is( $file, $dir, 'symlink reported in error' );

    $dir  = catdir('EXTRA', '3', 'U');
    $dir2 = catdir('EXTRA', '3', 'V');
    rmtree($dir, $dir2, {verbose => 0, error => \$err, result => \$list});
    is( scalar(@$list),  1, q{deleted 1 out of 2 directories} );
    is( scalar(@$error), 1, q{left behind 1 out of 2 directories} );
    eval { ($file, $message) = each %{$err->[0]} };
    is( $file, $dir, 'first dir reported in error' );
}

{
    $dir = catdir($tmp_base, 'ZZ');
    @created = mkpath($dir);
    is(scalar(@created), 1, "create a ZZ directory");

    local @ARGV = ($dir);
    rmtree( [grep -e $_, @ARGV], 0, 0 );
    ok(!-e $dir, "blow it away via \@ARGV");
}

SKIP : {
    my $skip_count = 19;
    #this test will fail on Windows, as per: http://perldoc.perl.org/perlport.html#chmod
    skip "Windows chmod test skipped", $skip_count
        if $^O eq 'MSWin32';
    my $mode;
    my $octal_mode;
    my @inputs = (
      0777, 0700, 0070, 0007,
      0333, 0300, 0030, 0003,
      0111, 0100, 0010, 0001,
      0731, 0713, 0317, 0371, 0173, 0137,
      00 );
    my $input;
    my $octal_input;
    $dir = catdir($tmp_base, 'chmod_test');

    foreach (@inputs) {
        $input = $_;
        @created = mkpath($dir, {chmod => $input});
        $mode = (stat($dir))[2];
        $octal_mode = S_IMODE($mode);
        $octal_input = sprintf "%04o", S_IMODE($input);
        is($octal_mode,$input, "create a new directory with chmod $input ($octal_input)");
        rmtree( $dir );
    }
}

SKIP: {
    my $skip_count = 8; # DRY
    skip "getpwent() not implemented on $^O", $skip_count
        unless $Config{d_getpwent};
    skip "getgrent() not implemented on $^O", $skip_count
        unless $Config{d_getgrent};
    skip 'not running as root', $skip_count
        unless $< == 0;
    skip "darwin's nobody and nogroup are -1", $skip_count
        if $^O eq 'darwin';

    my $dir_stem = $dir = catdir($tmp_base, 'owned-by');

    # find the highest uid ('nobody' or similar)
    my $max_uid   = 0;
    my $max_user = undef;
    while (my @u = getpwent()) {
        if ($max_uid < $u[2]) {
            $max_uid  = $u[2];
            $max_user = $u[0];
        }
    }
    skip 'getpwent() appears to be insane', $skip_count
        unless $max_uid > 0;

    # find the highest gid ('nogroup' or similar)
    my $max_gid   = 0;
    my $max_group = undef;
    while (my @g = getgrent()) {
        if ($max_gid < $g[2]) {
            $max_gid = $g[2];
            $max_group = $g[0];
        }
    }
    skip 'getgrent() appears to be insane', $skip_count
        unless $max_gid > 0;

    $dir = catdir($dir_stem, 'aaa');
    @created = make_path($dir, {owner => $max_user});
    is(scalar(@created), 2, "created a directory owned by $max_user...");
    my $dir_uid = (stat $created[0])[4];
    is($dir_uid, $max_uid, "... owned by $max_uid");

    $dir = catdir($dir_stem, 'aab');
    @created = make_path($dir, {group => $max_group});
    is(scalar(@created), 1, "created a directory owned by group $max_group...");
    my $dir_gid = (stat $created[0])[5];
    is($dir_gid, $max_gid, "... owned by group $max_gid");

    $dir = catdir($dir_stem, 'aac');
    @created = make_path($dir, {user => $max_user, group => $max_group});
    is(scalar(@created), 1, "created a directory owned by $max_user:$max_group...");
    ($dir_uid, $dir_gid) = (stat $created[0])[4,5];
    is($dir_uid, $max_uid, "... owned by $max_uid");
    is($dir_gid, $max_gid, "... owned by group $max_gid");

    SKIP: {
        skip 'Test::Output not available', 1
               unless $has_Test_Output;

        # invent a user and group that don't exist
        do { ++$max_user  } while (getpwnam($max_user));
        do { ++$max_group } while (getgrnam($max_group));

        $dir = catdir($dir_stem, 'aad');
        stderr_like(
            sub {make_path($dir, {user => $max_user, group => $max_group})},
            qr{\Aunable to map $max_user to a uid, ownership not changed: .* at \S+ line \d+
unable to map $max_group to a gid, group ownership not changed: .* at \S+ line \d+\b},
            "created a directory not owned by $max_user:$max_group..."
        );
    }
}

SKIP: {
    skip 'Test::Output not available', 13
        unless $has_Test_Output;

    SKIP: {
        $dir = catdir('EXTRA', '3');
        skip "extra scenarios not set up, see eg/setup-extra-tests", 3
            unless -e $dir;

        $dir = catdir('EXTRA', '3', 'U');
        stderr_like(
            sub {rmtree($dir, {verbose => 0})},
            qr{\Acannot make child directory read-write-exec for [^:]+: .* at \S+ line \d+},
            q(rmtree can't chdir into root dir)
        );

        $dir = catdir('EXTRA', '3');
        stderr_like(
            sub {rmtree($dir, {})},
            qr{\Acannot make child directory read-write-exec for [^:]+: .* at (\S+) line (\d+)
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2},
            'rmtree with file owned by root'
        );

        stderr_like(
            sub {rmtree('EXTRA', {})},
            qr{\Acannot remove directory for [^:]+: .* at (\S+) line (\d+)
cannot remove directory for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2
cannot unlink file for [^:]+: .* at \1 line \2
cannot restore permissions to \d+ for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2},
            'rmtree with insufficient privileges'
        );
    }

    my $base = catdir($tmp_base,'output');
    $dir  = catdir($base,'A');
    $dir2 = catdir($base,'B');

    is(_run_for_verbose(sub {@created = mkpath($dir, 1)}),
        "mkdir $base\nmkdir $dir\n",
        'mkpath verbose (old style 1)'
    );

    is(_run_for_verbose(sub {@created = mkpath([$dir2], 1)}),
        "mkdir $dir2\n",
        'mkpath verbose (old style 2)'
    );

    is(_run_for_verbose(sub {$count = rmtree([$dir, $dir2], 1, 1)}),
        "rmdir $dir\nrmdir $dir2\n",
        'rmtree verbose (old style)'
    );

    is(_run_for_verbose(sub {@created = mkpath($dir, {verbose => 1, mask => 0750})}),
        "mkdir $dir\n",
        'mkpath verbose (new style 1)'
    );

    is(_run_for_verbose(sub {@created = mkpath($dir2, 1, 0771)}),
        "mkdir $dir2\n",
        'mkpath verbose (new style 2)'
    );

    is(_run_for_verbose(sub {$count = rmtree([$dir, $dir2], 1, 1)}),
        "rmdir $dir\nrmdir $dir2\n",
        'again: rmtree verbose (old style)'
    );

    is(_run_for_verbose(sub {@created = make_path( $dir, $dir2, {verbose => 1, mode => 0711});}),
        "mkdir $dir\nmkdir $dir2\n",
        'make_path verbose with final hashref'
    );

    is(_run_for_verbose(sub {@created = remove_tree( $dir, $dir2, {verbose => 1});}),
        "rmdir $dir\nrmdir $dir2\n",
        'remove_tree verbose with final hashref'
    );

    # Have to re-create these 2 directories so that next block is not skipped.
    @created = make_path(
        $dir,
        $dir2,
        { mode => 0711 }
    );
    is(@created, 2, "2 directories created");

    SKIP: {
        $file = catdir($dir2, "file");
        skip "Cannot create $file", 2 unless open OUT, "> $file";
        print OUT "test file, safe to delete\n", scalar(localtime), "\n";
        close OUT;

        ok(-e $file, "file created in directory");

        is(_run_for_verbose(sub {$count = rmtree($dir, $dir2, {verbose => 1, safe => 1})}),
            "rmdir $dir\nunlink $file\nrmdir $dir2\n",
            'rmtree safe verbose (new style)'
        );
    }
}

SKIP: {
    skip "extra scenarios not set up, see eg/setup-extra-tests", 11
        unless -d catdir(qw(EXTRA 1));

    rmtree 'EXTRA', {safe => 0, error => \$error};
    is( scalar(@$error), 10, 'seven deadly sins' ); # well there used to be 7

    rmtree 'EXTRA', {safe => 1, error => \$error};
    is( scalar(@$error), 9, 'safe is better' );
    for (@$error) {
        ($file, $message) = each %$_;
        if ($file =~  /[123]\z/) {
            is(index($message, 'cannot remove directory: '), 0, "failed to remove $file with rmdir")
                or diag($message);
        }
        else {
            like($message, qr(\Acannot (?:restore permissions to \d+|chdir to child|unlink file): ), "failed to remove $file with unlink")
                or diag($message)
        }
    }
}

{
    my $base = catdir($tmp_base,'output2');
    my $dir  = catdir($base,'A');
    my $dir2 = catdir($base,'B');

    {
        my $warn;
        $SIG{__WARN__} = sub { $warn = shift };

        my @created = make_path(
            $dir,
            $dir2,
            { mode => 0711, foo => 1, bar => 1 }
        );
        like($warn,
            qr/Unrecognized option\(s\) passed to make_path\(\):.*?bar.*?foo/,
            'make_path with final hashref warned due to unrecognized options'
        );
    }

    {
        my $warn;
        $SIG{__WARN__} = sub { $warn = shift };

        my @created = remove_tree(
            $dir,
            $dir2,
            { foo => 1, bar => 1 }
        );
        like($warn,
            qr/Unrecognized option\(s\) passed to remove_tree\(\):.*?bar.*?foo/,
            'remove_tree with final hashref failed due to unrecognized options'
        );
    }
}

SKIP: {
    my $nr_tests = 6;
    my $cwd = getcwd() or skip "failed to getcwd: $!", $nr_tests;
    rmtree($tmp_base, {result => \$list} );
    is(ref($list), 'ARRAY', "received a final list of results");
    ok( !(-d $tmp_base), "test base directory gone" );

    my $p = getcwd();
    my $x = "x$$";
    my $xx = $x . "x";

    # setup
    ok(mkpath($xx), "make $xx");
    ok(chdir($xx), "... and chdir $xx");
    END {
         ok(chdir($p), "... now chdir $p");
         ok(rmtree($xx), "... and finally rmtree $xx");
    }

    # create and delete directory
    my $px = catdir($p, $x);
    ok(mkpath($px), 'create and delete directory 2.07');
    ok(rmtree($px), '.. rmtree fails in File-Path-2.07');
}

my $windows_dir = 'C:\Path\To\Dir';
my $expect = 'c:/path/to/dir';
is(
    File::Path::_slash_lc($windows_dir),
    $expect,
    "Windows path unixified as expected"
);

{
    my ($x, $message, $object, $expect, $rv, $arg, $error);
    my ($k, $v, $second_error, $third_error);
    local $! = 2;
    $x = $!;

    $message = 'message in a bottle';
    $object = '/path/to/glory';
    $expect = "$message for $object: $x";
    $rv = _run_for_warning( sub {
        File::Path::_error(
            {},
            $message,
            $object
        );
    } );
    like($rv, qr/^$expect/,
        "no \$arg->{error}: defined 2nd and 3rd args: got expected error message");

    $object = undef;
    $expect = "$message: $x";
    $rv = _run_for_warning( sub {
        File::Path::_error(
            {},
            $message,
            $object
        );
    } );
    like($rv, qr/^$expect/,
        "no \$arg->{error}: defined 2nd arg; undefined 3rd arg: got expected error message");

    $message = 'message in a bottle';
    $object = undef;
    $expect = "$message: $x";
    $arg = { error => \$error };
    File::Path::_error(
        $arg,
        $message,
        $object
    );
    is(ref($error->[0]), 'HASH',
        "first element of array inside \$error is hashref");
    ($k, $v) = %{$error->[0]};
    is($k, '', 'key of hash is empty string, since 3rd arg was undef');
    is($v, $expect, "value of hash is 2nd arg: $message");

    $message = '';
    $object = '/path/to/glory';
    $expect = "$message: $x";
    $arg = { error => \$second_error };
    File::Path::_error(
        $arg,
        $message,
        $object
    );
    is(ref($second_error->[0]), 'HASH',
        "first element of array inside \$second_error is hashref");
    ($k, $v) = %{$second_error->[0]};
    is($k, $object, "key of hash is '$object', since 3rd arg was defined");
    is($v, $expect, "value of hash is 2nd arg: $message");

    $message = '';
    $object = undef;
    $expect = "$message: $x";
    $arg = { error => \$third_error };
    File::Path::_error(
        $arg,
        $message,
        $object
    );
    is(ref($third_error->[0]), 'HASH',
        "first element of array inside \$third_error is hashref");
    ($k, $v) = %{$third_error->[0]};
    is($k, '', "key of hash is empty string, since 3rd arg was undef");
    is($v, $expect, "value of hash is 2nd arg: $message");
}

sub _run_for_warning {
    my $coderef = shift;
    my $warn;
    local $SIG{__WARN__} = sub { $warn = shift };
    &$coderef;
    return $warn;
}

sub _run_for_verbose {
    my $coderef = shift;
    my $stdout = '';
    close STDOUT;
    open STDOUT, '>', \$stdout;
    &$coderef;
    close STDOUT;
    return $stdout;
}
