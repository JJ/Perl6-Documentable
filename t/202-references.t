use Perl6::Documentable::Primary;
use Perl6::Documentable::Index;
use Pod::Load;
use Pod::Utilities;
use Pod::Utilities::Build;

use Test;

plan *;

my $pod = load("t/test-doc/Programs/02-reading-docs.pod6")[0];
my $origin = Perl6::Documentable::Primary.new(
    pod      => $pod,
    filename => "test",
);

my @names := ("url", "meta (multi)", "part", "nometa");
my %urls =
    "url"           => "/programs/test#index-entry-url-new_reference",
    "meta (multi)"  => "/programs/test#index-entry-multi__meta-part-no_meta_part",
    "part"          => "/programs/test#index-entry-multi__meta-part-no_meta_part",
    "nometa"        => "/programs/test#index-entry-nometa";

subtest "Reference detection" => {
    for $origin.refs -> $ref {
        is $ref.name ∈ @names, True, "$ref.name() detected";
    }
}

subtest "URL handling" => {
    for $origin.refs -> $ref {
        is $ref.url, %urls{$ref.name()}, "$ref.name() url";
    }
}

subtest "leading whitespace references" => {
    my $reference = Pod::FormattingCode.new(
        type     => 'X',
        meta => [["meta", " meta1"]],
    );
    my @references = Perl6::Documentable::Index.new(
        pod    => $reference,
        origin => Perl6::Documentable::Primary,
        meta   => [["meta", " meta1"]]
    );
    for @references -> $ref {
        is $ref.name.starts-with(" "), False, "leading whitespace";
    }
}

done-testing;