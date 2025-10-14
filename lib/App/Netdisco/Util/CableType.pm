package App::Netdisco::Util::CableType;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw/
  build_port_lookup
  find_port_in_text
  module_medium
  infer_port_medium
  choose_medium
  color_for_medium
  medium_rank
/;

my @MEDIUM_PRIORITY_ORDER = qw/aoc dac copper single_mode om3_mmf om1_mmf/;
my %MEDIUM_PRIORITY = map { $MEDIUM_PRIORITY_ORDER[$_] => scalar(@MEDIUM_PRIORITY_ORDER) - $_ }
  0 .. $#MEDIUM_PRIORITY_ORDER;

my %MEDIUM_COLORS = (
  aoc         => 'black',
  dac         => 'black',
  copper      => 'blue',
  single_mode => 'yellow',
  om3_mmf     => 'aqua',
  om1_mmf     => 'orange',
);

my %MEDIUM_PATTERNS = (
  aoc => [
    qr/\bAOC\b/i,
    qr/ACTIVE\s*OPTICAL/i,
  ],
  dac => [
    qr/\bDAC\b/i,
    qr/DIRECT\s*ATTACH/i,
    qr/TWINAX/i,
    qr/\bCU\d{0,2}M\b/i,
    qr/\bH\d+GB-?CU\d*M\b/i,
    qr/PASSIVE\s+COPPER/i,
  ],
  copper => [
    qr/\bBASE[-\s]?T\b/i,
    qr/RJ-?45/i,
    qr/\bGLC-(?:T|TE)\b/i,
    qr/\bSFP-GE-T\b/i,
    qr/COPPER/i,
  ],
  single_mode => [
    qr/(?:^|[-_ ])(?:LR|ER|ZR|LX|LH|SM|ZX|BX\d*|EX)(?:[-_ ]|$)/i,
    qr/\bSINGLE\s*MODE\b/i,
    qr/\bSMF\b/i,
    qr/\bBIDI\b/i,
  ],
  om3_mmf => [
    qr/(?:^|[-_ ])(?:SR|CSR|SR\d{1,2}|SRBD)(?:[-_ ]|$)/i,
    qr/\bOM[34]\b/i,
    qr/850\s*NM/i,
  ],
  om1_mmf => [
    qr/(?:^|[-_ ])(?:SX|FX|LRM)(?:[-_ ]|$)/i,
    qr/\bOM1\b/i,
    qr/MMF/i,
  ],
);

my %PREFIX_ALIASES = (
  'gigabitethernet'       => [qw/GigabitEthernet Gi GE/],
  'gi'                    => [qw/Gi GigabitEthernet GE/],
  'tengigabitethernet'    => [qw/TenGigabitEthernet Te TenGigE XGE/],
  'te'                    => [qw/Te TenGigabitEthernet TenGigE XGE/],
  'fastethernet'          => [qw/FastEthernet Fa FE/],
  'fa'                    => [qw/Fa FastEthernet FE/],
  'ethernet'              => [qw/Ethernet Eth Et/],
  'et'                    => [qw/Et Eth Ethernet/],
  'hundredgigabitethernet'=> [qw/HundredGigabitEthernet Hu HundredGigE/],
  'hundredgige'           => [qw/HundredGigE Hu HundredGigabitEthernet/],
  'hu'                    => [qw/Hu HundredGigE HundredGigabitEthernet/],
  'fortygigabitethernet'  => [qw/FortyGigabitEthernet Fo FortyGigE/],
  'fortygige'             => [qw/FortyGigE Fo FortyGigabitEthernet/],
  'fo'                    => [qw/Fo FortyGigabitEthernet FortyGigE/],
  'twentygigabitethernet' => [qw/TwentyGigabitEthernet Tw TwentyGigE/],
  'tw'                    => [qw/Tw TwentyGigabitEthernet TwentyGigE/],
  'twentyfivegigabitethernet' => [qw/TwentyFiveGigabitEthernet Twe TwentyFiveGigE/],
  'twentyfivegige'        => [qw/TwentyFiveGigE Twe TwentyFiveGigabitEthernet/],
  'twe'                   => [qw/Twe TwentyFiveGigabitEthernet TwentyFiveGigE/],
  'fiftygigabitethernet'  => [qw/FiftyGigabitEthernet Fi FiftyGigE/],
  'fiftygige'             => [qw/FiftyGigE Fi FiftyGigabitEthernet/],
  'fi'                    => [qw/Fi FiftyGigabitEthernet FiftyGigE/],
  'twogigabitethernet'    => [qw/TwoGigabitEthernet TwoGigE Tg/],
  'twogige'               => [qw/TwoGigE Tg TwoGigabitEthernet/],
  'tg'                    => [qw/Tg TwoGigabitEthernet TwoGigE/],
  'port-channel'          => [qw/Port-channel PortChannel Po PO/],
  'portchannel'           => [qw/PortChannel Port-channel Po PO/],
  'po'                    => [qw/Po Port-channel PortChannel/],
  'bundle-ether'          => [qw/Bundle-Ether BundleEther BE/],
  'bundleether'           => [qw/BundleEther Bundle-Ether BE/],
  'be'                    => [qw/BE Bundle-Ether BundleEther/],
  'mgmtethernet'          => [qw/mgmtEth MgmtEth ManagementEthernet/],
  'managementethernet'    => [qw/ManagementEthernet MgmtEth/],
  'loopback'              => [qw/Loopback Lo/],
  'lo'                    => [qw/Lo Loopback/],
  'vlan'                  => [qw/Vlan Vl/],
  'vl'                    => [qw/Vl Vlan/],
);

sub medium_from_string {
  my $string = shift;
  return unless defined $string;

  foreach my $medium (@MEDIUM_PRIORITY_ORDER) {
    foreach my $pattern (@{ $MEDIUM_PATTERNS{$medium} }) {
      return $medium if $string =~ $pattern;
    }
  }

  return;
}

sub module_medium {
  my $module = shift or return;

  return medium_from_string($module->model)
      || medium_from_string($module->description)
      || medium_from_string($module->name);
}

sub infer_port_medium {
  my $port = shift or return;

  return medium_from_string($port->type)
      || medium_from_string($port->descr)
      || medium_from_string($port->name);
}

sub choose_medium {
  my ($current, $candidate) = @_;

  return $candidate unless defined $current;
  return $current unless defined $candidate;
  return $candidate if medium_rank($candidate) > medium_rank($current);
  return $current;
}

sub medium_rank {
  my $medium = shift;
  return 0 unless defined $medium;
  return $MEDIUM_PRIORITY{$medium} || 0;
}

sub color_for_medium {
  my $medium = shift;
  return $MEDIUM_COLORS{$medium};
}

sub port_aliases {
  my $port = shift;
  return () unless defined $port;

  my $trimmed = $port;
  $trimmed =~ s/\s+//g;

  my %aliases = ($trimmed => 1, $port => 1);

  if ($trimmed =~ /^([A-Za-z-]+)([A-Za-z0-9\/:.\-]*)$/) {
    my ($prefix, $suffix) = ($1, $2);
    my $lower = lc $prefix;
    my @prefixes = ($prefix);
    push @prefixes, @{ $PREFIX_ALIASES{$lower} } if exists $PREFIX_ALIASES{$lower};

    $suffix =~ s/\s+//g;
    foreach my $pref (@prefixes) {
      next unless defined $pref && length $pref;
      my $alias = $pref . $suffix;
      $aliases{$alias} = 1;
    }
  }

  if ($trimmed =~ /(\d+(?:[\/:]\d+)+)$/) {
    $aliases{$1} = 1;
  }

  return keys %aliases;
}

sub build_port_lookup {
  my $ports = shift || {};
  my %lookup;

  return \%lookup unless ref $ports eq 'HASH';

  foreach my $port (keys %$ports) {
    foreach my $alias (port_aliases($port)) {
      my $norm = normalize_alias($alias);
      next unless length $norm;
      $lookup{$norm} ||= $port;
    }
  }

  return \%lookup;
}

sub find_port_in_text {
  my ($text, $lookup) = @_;
  return unless defined $text && $lookup && ref $lookup eq 'HASH';

  foreach my $token (_tokenize($text)) {
    my $norm = normalize_alias($token);
    next unless length $norm;
    if (my $port = $lookup->{$norm}) {
      return $port;
    }
  }

  return;
}

sub normalize_alias {
  my $alias = shift;
  return '' unless defined $alias;

  my $norm = lc $alias;
  $norm =~ s/\s+//g;
  $norm =~ s/[^a-z0-9\/:]//g;

  return $norm;
}

sub _tokenize {
  my $text = shift;
  return () unless defined $text;

  my @tokens = ($text =~ /([A-Za-z][A-Za-z0-9\/:.\-]*\d+[A-Za-z0-9\/:.\-]*)/g);
  push @tokens, ($text =~ /(\d+(?:[\/:]\d+)+)/g);

  return @tokens;
}

1;
