#!/usr/bin/perl -w
# Build file for CKEditor plugin
#
# Standard preamble
BEGIN {
  foreach my $pc (split(/;/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

package CKEditorPluginBuild;
use Foswiki::Contrib::Build;
use File::Copy;
use File::Find;
use JavaScript::Minifier;
use CSS::Minifier;

our @ISA = qw( Foswiki::Contrib::Build );

my $pname = "CKEditorPlugin";

# BUILD CONFIGURATION {{{

# CKPackager info file to use
my $packager_file = "ckeditor.pack";

# Exclude CKPackaged files from preprocessing?
my $exclude_packaged = 1;

# Files to be preprocessed/copied (stuff we need to minify/filter)
# Trailing slash on both sides means that it's a directory and we'll
# recursively process everything in it automatically.
my %preprocess_files = (
);

# Definitely ignore these files (backup files, swap files, etc.)
# Regular expression syntax
# Only applies to the automatic recursive processing above, obviously
my @preprocess_ignore = (
	'\.swp$', '\~$', '\.xcf$'
);

# Should the unprocessed versions of the files be included, too?
my $preprocess_include_original = 1;

# This one automatically populates %preprocess_files.
#
# An entry like 'foo%.js' will generate a key-value pair like this:
#     'foo_source.js' => 'foo.js'
# An entry like '%%adapters/' will expand like this (slash added on left
# side):
#     '_source/adapters/' => 'adapters/'
my @preprocess_files_auto = qw(
	%%adapters/ %%core/ %%lang/ %%plugins/ %%skins/kama/ %%themes/
	foswiki_cke%.js foswiki%.js
	modacContents%.css
);

# Files to be used as-is within scripts dir
# This list includes files built by the first step, CKPackager
my @include_files = qw(
	ckeditor.js ckeditor_source.js
	ckeditor_basic.js ckeditor_basic_source.js
	contents.css
	config.js
	images/bullet.gif
	images/profi.gif
	images/spacer.gif
);

# Other files to be included in package, relative to plugin root
# Suffices parsed out of the names:
# !  executable, 0755
# +  read-only, 0444
# #  executable read-only, 0555
# By default, 0644 will be used.
my @include_files_base = (
	"data/System/AjaxHelper.txt",
	"data/System/$pname.txt",
	"lib/Foswiki/Configure/Checkers/Plugins/$pname/Enabled.pm",
	"lib/Foswiki/Plugins/$pname.pm",
	"lib/Foswiki/Plugins/$pname/DEPENDENCIES",
	"pub/System/$pname/screenshot.png",
);

# BUILD CONFIGURATION }}}

for (@preprocess_files_auto) {
	my $key = $_;
	s(%%|%)()g;
	$key =~ s(%%)(_source/)g;
	$key =~ s(%)(_source)g;
	$preprocess_files{$key} = $_;
}

sub _readfile {
	my $name = shift;
	open(IN, "<", $name) or die "Can't open `$name' for reading: $!";
	my @data = grep { !/\@Packager\.RemoveLine/ } <IN>;
	close(IN);
	return join('', @data);
}

sub _writefile {
	my ($name, $data) = @_;
	open(OUT, ">", $name) or die "Can't open `$name' for writing: $!";
	print OUT $data;
	close(OUT);
}

sub _minify {
	my ($source, $target) = @_;
	if ($source !~ /\.(?:css|js)$/) {
		copy($source, $target);
		return;
	}
	if ($source =~ /\.css$/) {
		my $css = _readfile($source);
		_writefile($target, CSS::Minifier::minify(input => $css));
	} else {
		my $js = _readfile($source);
		_writefile($target, JavaScript::Minifier::minify(input => $js));
	}
}

sub new {
	my $class = shift;
	return bless( $class->SUPER::new( $pname ));
}

# Override build target to do CKEditor-specific preprocessing
# prior to doing the build proper
sub target_build {
	my $this = shift;
	# - Generate MANIFEST while we work
	my @manifest;
	my $scriptpath = "pub/System/$pname/ckeditor";
	my $scriptpath_full = "$this->{basedir}/$scriptpath";
	my $stampfile = "prebuild.stamp";
	$this->pushd($scriptpath_full);
	if (-f $stampfile) {
		my $stamp = _readfile($stampfile);
		chomp $stamp;
		if ((time - $stamp) <= 120) {
			print "Using recently performed CKEditorPlugin prebuild\n";
			$this->popd();
			return $this->SUPER::target_build(@_);
		}
		print STDERR "WARNING: prebuild was more than two minutes ago; redoing to be safe\n";
		unlink $stampfile;
	}
	my $pack = _readfile($packager_file);
	print <<BANNER;
CKEditorPlugin prebuild step
============================

Since CKEditor has its own ideas of how to structure its file tree,
a prebuild step is needed with our own minification and copying.
For developer convenience, the prebuild step also (re)builds the MANIFEST
file. Since Foswiki's build tools don't re-read the MANIFEST file,
you will have to re-run your build command after this run completes.

Please ignore any warnings during the prebuild about files in the MANIFEST.
BANNER
	# - Pack pub/System/CKEditorPlugin/ckeditor/ckeditor.js
	local $| = 1;
	print "Packaging ckeditor.js using CKPackager...";
	$this->sys_action(qw(java -jar ckpackager.jar), $packager_file);
	print " done.\n";
	# - Preprocess and minify files in pub/System/CKEditorPlugin/ckeditor/_source
	#   (and a few extra files)
	for (@include_files) {
		push @manifest, "$scriptpath/$_ 0644";
	}
	for (@include_files_base) {
		my $perm = '0644';
		if (/!$/) {
			$perm = '0755';
		} elsif (/\+$/) {
			$perm = '0444';
		} elsif (/#$/) {
			$perm = '0555';
		}
		s/[!#+]$//;
		push @manifest, "$_ $perm";
	}
	print "Prebuilding:";
	for my $entry (keys %preprocess_files) {
		if ($entry =~ m(/$)) {
			find({no_chdir => 1, wanted => sub {
				my $target = $_;
				# Temporarily add trailing slash so that substitution works
				$target .= '/' if -d;
				$target =~ s(^$entry)($preprocess_files{$entry});
				$target =~ s(/$)();
				for my $ign (@preprocess_ignore) {
					return if ($_ =~ /$ign/);
				}
				my @parts = split('/', $target);
				# Only show "major components"
				print " $target" if @parts < 3 && $target !~ m(^core/|^_source/);
				if (-d) {
					if (!-d $target && $target !~ m(^core/)) {
						mkdir($target) or die "Trying to create directory $target failed: $!";
					}
					return;
				}
				if (m(_source/core)) {
					push @manifest, "$scriptpath/$_ 0644" if $preprocess_include_original;
					return;
				}
				if (!$exclude_packaged || $pack !~ /^\s+'\Q$_\E',\s*$/m) {
					_minify($_, $target);
					push @manifest, "$scriptpath/$target 0644";
				}
				push @manifest, "$scriptpath/$_ 0644" if $preprocess_include_original;
			}}, $entry);
		} else {
			# Single file
			my $target = $preprocess_files{$entry};
			print " $target";
			_minify($entry, $target);
			push @manifest, "$scriptpath/$target 0644";
			push @manifest, "$scriptpath/$entry 0644" if $preprocess_include_original;
		}
	}
	print "\nBuilding MANIFEST\n";
	_writefile("$this->{basedir}/lib/Foswiki/Plugins/$pname/MANIFEST", join("\n", sort {lc($a) cmp lc($b)} @manifest));
	print <<COMPL_MSG;
$pname prebuild complete. Due to how Foswiki's build tools work,
you now have to restart the build process. The pre-processing will be
skipped this time.

COMPL_MSG
	open(my $fh, '>', "prebuild.stamp") or die "Could not stamp prebuild: $!";
	print $fh time();
	exit;
}

# Create MANIFEST file if none exists yet
use File::Spec;
my ($spec_vol, $spec_path) = File::Spec->splitpath(__FILE__);
my $mani_path = File::Spec->catfile($spec_vol.$spec_path, 'MANIFEST');
if (!-f $mani_path) {
	open(MANI, '>', $mani_path) or die "Cannot create $mani_path: $!";
	close(MANI);
}

# Create the build object
$build = new CKEditorPluginBuild();

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://extensions.open-quality.com/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://extensions.open-quality.com/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build($build->{target});

