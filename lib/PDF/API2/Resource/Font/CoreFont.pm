package PDF::API2::Resource::Font::CoreFont;

use base 'PDF::API2::Resource::Font';

use strict;
use warnings;

# VERSION

use File::Basename;

use PDF::API2::Util;
use PDF::API2::Basic::PDF::Utils;

# Windows fonts with Type1 equivalents
my $alias = {
    'arial'           => 'helvetica',
    'arialitalic'     => 'helveticaoblique',
    'arialbold'       => 'helveticabold',
    'arialbolditalic' => 'helveticaboldoblique',

    'times'                   => 'timesroman',
    'timesnewromanbolditalic' => 'timesbolditalic',
    'timesnewromanbold'       => 'timesbold',
    'timesnewromanitalic'     => 'timesitalic',
    'timesnewroman'           => 'timesroman',

    'couriernewbolditalic' => 'courierboldoblique',
    'couriernewbold'       => 'courierbold',
    'couriernewitalic'     => 'courieroblique',
    'couriernew'           => 'courier',
};

=head1 NAME

PDF::API2::Resource::Font::CoreFont - Module for using the 14 standard PDF fonts.

=head1 SYNOPSIS

    my $pdf = PDF::API2->new();
    my $font = $pdf->font('Times-Roman');

    my $page = $pdf->page();
    my $text = $page->text();
    $text->font($font, 20);
    $text->translate(200, 700);
    $text->text('Hello world!');

    $pdf->to_file('/path/to/new.pdf');

=head1 STANDARD FONTS

The following fourteen fonts are available in all PDF readers that conform to
the PDF specification:

=over

=item * Courier

=item * Courier-Bold

=item * Courier-BoldOblique

=item * Courier-Oblique

=item * Helvetica

=item * Helvetica-Bold

=item * Helvetica-BoldOblique

=item * Helvetica-Oblique

=item * Symbol

=item * Times-Bold

=item * Times-BoldItalic

=item * Times-Italic

=item * Times-Roman

=item * ZapfDingbats

=back

These fonts (except Symbol and ZapfDingbats) include glyphs for ASCII and
certain Latin characters only.  If other characters are needed, you will need to
embed a font file.

=cut

sub _look_for_font {
    my $name = shift();
    eval "require PDF::API2::Resource::Font::CoreFont::$name";
    if ($@) {
        die "requested font '$name' not installed";
    }

    my $class = "PDF::API2::Resource::Font::CoreFont::$name";
    my $font = _deep_copy($class->data());
    $font->{'uni'} ||= [];
    foreach my $n (0..255) {
        unless (defined $font->{'uni'}->[$n]) {
            $font->{'uni'}->[$n] = uniByName($font->{'char'}->[$n]);
        }
    }
    return %$font;
}

# Deep copy something, thanks to Randal L. Schwartz
# Changed to deal with code refs, in which case it doesn't try to deep copy
sub _deep_copy {
    my $this = shift();
    no warnings 'recursion';
    unless (ref($this)) {
        return $this;
    }
    elsif (ref($this) eq 'ARRAY') {
        return [ map { _deep_copy($_) } @$this];
    }
    elsif (ref($this) eq 'HASH') {
        return +{ map { $_ => _deep_copy($this->{$_}) } keys %$this };
    }
    elsif (ref $this eq "CODE") {
        # Can't deep copy code refs
        return $this;
    }
    else {
        die 'Unable to copy a ' . ref($this);
    }
}

sub new {
    my ($class, $pdf, $name, %options) = @_;
    my $data;

    if (-f $name) {
        eval "require '$name'";
        $name = basename($name, '.pm');
    }

    my $lookname = lc($name);
    $lookname =~ s/[^a-z0-9]+//gi;
    $lookname = $alias->{$lookname} if $alias->{$lookname};

    $options{'-encode'} ||= 'asis';
    unless (defined $options{'-metrics'}) {
        $data = { _look_for_font($lookname) };
    }
    else {
        $data = { %{$options{'-metrics'}} };
    }

    die "Undefined font '$name($lookname)'" unless $data->{'fontname'};

    $class = ref($class) if ref($class);
    my $self = $class->SUPER::new($pdf, $data->{'apiname'} . pdfkey() . '~' . time());
    $pdf->new_obj($self) unless $self->is_obj($pdf);
    $self->{' data'} = $data;
    $self->{'-dokern'} = 1 if $options{'-dokern'};

    $self->{'Subtype'} = PDFName($self->data->{'type'});
    $self->{'BaseFont'} = PDFName($self->fontname());
    if ($options{'-pdfname'}) {
        $self->name($options{'-pdfname'});
    }

    unless ($self->data->{'iscore'}) {
        $self->{'FontDescriptor'} = $self->descrByData();
    }

    $self->encodeByData($options{'-encode'});

    return $self;
}

1;
