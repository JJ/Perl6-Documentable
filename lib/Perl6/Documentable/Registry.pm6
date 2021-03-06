use Pod::Load;
use Pod::Utilities;
use Pod::To::Cached;
use Pod::Utilities::Build;

use URI::Escape;
use Perl6::Documentable::Utils::IO;
use Perl6::TypeGraph;
use Perl6::Documentable;
use Perl6::Documentable::Primary;

use Perl6::Documentable::LogTimelineSchema;

unit class Perl6::Documentable::Registry;

has                  @.documentables;
has                  @.definitions;
has                  @.references;
has                  @.docs;
has Bool             $.composed;
has                  %.cache;
has Perl6::TypeGraph $.tg;
has                  %.routines-by-type;

has Pod::To::Cached $.pod-cache;
has Bool            $.use-cache;

has Bool $.verbose;
has Str  $.topdir;

submethod BUILD (
    Str     :$topdir     = "doc",
            :@dirs       = [],
    Bool    :$verbose    = True,
    Bool    :$use-cache  = True,
    Str     :$typegraph-file?
) {
    $!verbose     = $verbose;
    $!use-cache   = $use-cache;
    if ($typegraph-file) {
        $!tg = Perl6::TypeGraph.new-from-file($typegraph-file);
    } else {
        $!tg = Perl6::TypeGraph.new-from-file;
    }
    $!topdir      = $topdir.IO.absolute;

    # init cache if needed
    if ( $!use-cache ) {
        my $cache-dir = cache-path($!topdir);

        if ($cache-dir.IO.e) {
            note "$cache-dir directory will be used as a cache. " ~
                 "Please do not use any other directory with "    ~
                 "this name." if $!verbose;
        }

        $!pod-cache = Pod::To::Cached.new(
            source      => $!topdir,
            :$!verbose,
            path        => $cache-dir
        );
        $!pod-cache.update-cache;
    }

    # initialize the registry
    for @dirs -> $dir {
        self.process-pod-dir(:$dir).map(
            -> $doc {
            self.add-new( :$doc )
        });
    }
}

method add-new(Perl6::Documentable::Primary :$doc --> Perl6::Documentable::Primary) {
    die "Cannot add something to a composed registry" if $.composed;
    @!documentables.append: $doc;
    $doc;
}

method load (Str :$path --> Positional[Pod::Block::Named]) {
    my $topdir = $!topdir;
    my Pod::Block::Named @pods;
    if ( $!use-cache ) {
        # topdir/dir/file.pod6 => dir/file
        my $new-path = $path.subst(/$topdir/, "")
                       .subst(/\.pod6/, "").lc
                       .subst(/^\//, ''); # leading /
        @pods = $!pod-cache.pod( $new-path );
    } else {
        @pods = load($path);
    }

    return @pods;
}

method process-pod-dir(Str :$dir --> Array) {
    # pods to process
    my @pod-files = get-pod-names(:$!topdir, :$dir);
    for @pod-files.kv -> $num, (:key($filename), :value($file)) {
        my @pod-fragments = self.load(path => $file.path);
        for @pod-fragments -> $pod {
            Perl6::Documentable::LogTimeline::New.log: :$filename, -> {
                my $doc =Perl6::Documentable::Primary.new(
                    pod      => $pod,
                    filename => $filename,
                );

                self.add-new: :$doc;
            }
        }
    }
}

# consulting logic

method compose() {
    @!definitions = [$_.defs.Slip for @!documentables];
    @!references  = [$_.refs.Slip for @!documentables];
    @!docs = @!documentables.Slip, @!definitions.Slip, @!references.Slip;
    %!routines-by-type = @!definitions.grep({.kind eq Kind::Routine})
                                      .classify({.origin.name});

    $!composed = True;
}

method lookup(Str $what, Str :$by!) {

    unless %!cache{$by}:exists {
        for @!docs -> $d {
            %!cache{$by}{$d."$by"()}.append: $d;
        }
    }
    %!cache{$by}{$what} // [];
}

method docs-for(Str $name) {
    @!docs.grep({.name eq $name})
}

# vim: expandtab shiftwidth=4 ft=perl6