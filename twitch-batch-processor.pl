#!/usr/bin/env perl

package StreamFactory;

sub create {
	my (%args) = @_;
	my ($fileProcessor) = @args{qw(fileProcessor)};
	my $fileName = $fileProcessor->fileName;

	if ($fileName =~ m/^(\w+) \((live|rerun)\)\s+/) {
		return StreamInfo->new(name => $1);
	}

	return undef;
}

package StreamInfo;
use Moose;

has name => (is => 'ro', isa => 'Str', required => 1);
has keepVideo => (is => 'rw', isa => 'Bool', lazy => 1, builder => '__makeKeepVideo');
has speedProblem => (is => 'rw', isa => 'Bool', lazy => 1, builder => '__makeSpeedProblem');

sub __makeKeepVideo {
	my ($self) = @_;

	my @dontKeepArr = ( # unreferenced variable to avoid keeping video because of electricity cost
		'AleksCraine',
		'Eternal_XTC',
		'OfficialJES',
		'liammelly',
		'LionaStone',
		'MIKEPush',
		'RinalyMusic',
		'gabrielanddresden',
		'HANAWINS',
		'floridauplifting',
		'Kailey_Grace',
		'very_squishy_fox',
		'taucher66',
		'LoaLaLunaDj',
		'AlessandraRoncone_music',
		'syrianna_',
		'ThugShells',
		'JskaDwn',
	);

	my @keepArr = (
		'amelia000000',
		'IdiotWithAGrill',
		'JenniferReneMusic',
		'LeeJOfficial',
		'leejofficial',
		'leejtranzalitystudios',
		'LuminosityEvents',
		'zoyasmusic',
	);

	my %keep = map { $_ => 1 } @keepArr;
	return $keep{ $self->name } || 0;
}

sub __makeSpeedProblem {
	my ($self) = @_;

	my @speedArr = (
		'angelrun1',
		'A_D_A_M_S_K_I',
		'bootey',
		'CarteBlanche88',
		'c6_dj',
		'clairey6',
		'DJ_Shorty_K',
		'ForcyteOfficial',
		'Lange',
		'LangeDJ',
		'limin_li',
		'MaryLe_Mar',
		'maryle_mar',
		'Stoneface_Terminal',
		'talla2xlc',
		'The_Real_DJ_Edit',
		'TheReal_DJEdit',
		'trancejesus',
		'VlastimilVibes',
		'xDER_LORDx',
		'zzzorza',
		'KennedY_DJ',
	);

	my %speed = map { $_ => 1 } @speedArr;
	return $speed{ $self->name } || 0;
}

package TypeAnal;
use Moose;
use Moose::Util::TypeConstraints;
use Readonly;

Readonly our $AUDIO   => 'audio';
Readonly our $UNKNOWN => 'unknown';
Readonly our $VIDEO   => 'video';

has extension => (is => 'ro', isa => 'Str', required => 1);

enum Type => [qw(audio unknown video)];

has fileType => (is => 'rw', isa => 'Type', lazy => 1, builder => '__makeType');

sub __makeType {
	my ($self) = @_;

	return $AUDIO if ($self->extension eq 'm4a');
	return $AUDIO if ($self->extension eq 'mp3');

	return $VIDEO if ($self->extension eq 'mkv');
	return $VIDEO if ($self->extension eq 'mp4');

	return $UNKNOWN;
}

package FileProcessor;
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use File::Copy;

has [qw(directoryPath fileName fullPath fileStat)] => (isa => 'Str', is => 'ro', required => 1);
has fileStat => (isa => 'File::stat', is => 'ro', required => 1);
has interesting => (is => 'rw', isa => 'Bool', builder => '__makeInteresting', lazy => 1);
has extension => (is => 'rw', isa => 'Str', init_arg => undef, lazy => 1, builder => '__makeExtension');

sub __makeInteresting {
	my ($self) = @_;

	my $anal = TypeAnal->new(extension => $self->extension);
	return 0 if ($anal->fileType eq $UNKNOWN);

	return 1;
}

sub __makeExtension {
	my ($self) = @_;

	return (split(m/\./, $self->fileName))[-1]; # Last part
}

sub __trapUninteresting {
	my ($self) = @_;

	die("run() called for uninteresting file: '" . $self->fullPath . "'")
	    unless ($self->interesting);
}

sub phase1 {
	my ($self) = @_;

	printf("%s\n", $self->fullPath);
	my $stream = StreamFactory::create(fileProcessor => $self);
	return EXIT_FAILURE unless ($stream);

	my $outDir = $Script::OUTPUT_PHASE_ONE_AUDIO;
	if ($stream->keepVideo) {
		$outDir = $Script::OUTPUT_PHASE_ONE_VIDEO;
	} elsif ($stream->speedProblem) {
		$outDir = $Script::OUTPUT_PHASE_ONE_SPEED;
	}

	my $target = join('/', $outDir, $self->fileName);
	printf("mv '%s' -> '%s'\n", $self->fullPath, $target);
	move($self->fullPath, $target);
}

sub phase2 {
	my ($self) = @_;

	# This is presently a no-op as we work at directory level in phase 2
}

sub run {
	my ($self) = @_;

	$self->__trapUninteresting();

	$self->phase1();

	return EXIT_SUCCESS;
}

package Script;
use File::stat;
use Fcntl ':mode';
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;

Readonly our $INPUT_PHASE_ONE      => '/var/tmp/palmer/Twitch_Incoming';
Readonly our $OUTPUT_PHASE_ONE_AUDIO => "${INPUT_PHASE_ONE}/mp3";
Readonly our $OUTPUT_PHASE_ONE_VIDEO => "${INPUT_PHASE_ONE}/keep-720p";
Readonly our $OUTPUT_PHASE_ONE_SPEED => "${INPUT_PHASE_ONE}/speed";
Readonly our $TAGGING_DIR => "${INPUT_PHASE_ONE}/tag";

sub phase1 {
	my ($self, $dirname) = @_;
	my $exitCode = EXIT_SUCCESS;

	local *dirHandle;
	if (opendir(dirHandle, $dirname)) {
		while (my $filename = readdir(dirHandle)) {
			next if (substr($filename, 0, 1) eq '.'); # skip all hidden files

			# Special directories which are outputs from phase 1
			next if ($filename eq 'mp3');
			next if ($filename =~ /^keep/);
			next if ($filename =~ 'speed');

			# There are some historical files I need to skip while we get into the new routine
			next if ($filename eq 'RinalyMusic');
			next if ($filename eq '424e865c-f2c9-11ec-8216-230b7d482a44');
			next if ($filename eq 'HANAWINS');
			next if ($filename eq 'ThugShells');

			# Must be skipped on all phases
			next if ($filename eq 'ready'); # Output from phase 2

			my $fullPath = join('/', $dirname, $filename);

			my $stat = stat($fullPath);
			if (S_ISDIR($stat->mode)) {
				$exitCode = $self->phase1($fullPath);
			} else {
				my $fileProcessor = FileProcessor->new(
					directoryPath => $dirname,
					fileName      => $filename,
					fullPath      => $fullPath,
					fileStat      => $stat,
				);

				if ($fileProcessor->interesting) {
					$exitCode = $fileProcessor->run();
				}
			}
		}
	}

	return $exitCode;
}

sub phase2 {
	my ($self, $fullPath, $mode) = @_;

	my $exitCode = EXIT_SUCCESS;

	return EXIT_FAILURE unless (chdir($fullPath));

	if ($mode eq 'mp3') {
		$exitCode = $self->__mp4_to_mp3();
	} elsif ($mode eq 'speed') {
		$exitCode = $self->__mp4_to_mp3();
		if ($exitCode == EXIT_SUCCESS) {
			$exitCode = $self->__speedFix();
		}
	} elsif ($mode eq 'mp4') {
		$exitCode = $self->__720p();
	}

	if ($exitCode == EXIT_SUCCESS) {
		$exitCode = system('mv', '-v', '*', "${TAGGING_DIR}/");
	}

	return $exitCode;
}

sub __mp4_to_mp3 {
	my ($self) = @_;

	system('mp4-to-mp3');
	system('mp3-desilence');

	return EXIT_SUCCESS;
}

sub __speedFix {
	my ($self) = @_;

	system('twitch-speed-fix-mp3');

	return EXIT_SUCCESS;
}

sub __720p {
	my ($self) = @_;

	if (glob('*.mkv')) {
		system('mp4-to-mkv-720p');
	}

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
use POSIX qw(EXIT_SUCCESS);

sub main {
	Script->new->phase1($INPUT_PHASE_ONE);

	my %DIR = (
		$OUTPUT_PHASE_ONE_AUDIO => 'mp3',
		$OUTPUT_PHASE_ONE_VIDEO => 'mp4',
		$OUTPUT_PHASE_ONE_SPEED => 'speed',
	);

	while (my ($dir, $mode) = each(%DIR)) {
		Script->new->phase2($dir, $mode);
	}

	return EXIT_SUCCESS;
}

exit(main()) unless (caller());
