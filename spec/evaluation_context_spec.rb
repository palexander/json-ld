# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe JSON::LD::EvaluationContext do
  before(:each) {
    @debug = []
    @ctx_json = %q({
      "@context": {
        "name": "http://xmlns.com/foaf/0.1/name",
        "homepage": {"@id": "http://xmlns.com/foaf/0.1/homepage", "@type": "@id"},
        "avatar": {"@id": "http://xmlns.com/foaf/0.1/avatar", "@type": "@id"}
      }
    })
  }
  subject { JSON::LD::EvaluationContext.new(:debug => @debug, :validate => true)}

  describe "#parse" do
    context "remote" do
      before(:each) do
        @ctx = StringIO.new(@ctx_json)
        def @ctx.content_type; "application/ld+json"; end
      end

      it "retrieves and parses a remote context document" do
        subject.stub(:open).with("http://example.com/context").and_yield(@ctx)
        ec = subject.parse("http://example.com/context")
        ec.provided_context.should produce("http://example.com/context", @debug)
      end

      it "fails given a missing remote @context" do
        subject.stub(:open).with("http://example.com/context").and_raise(IOError)
        lambda {subject.parse("http://example.com/context")}.should raise_error(IOError, /Failed to parse remote context/)
      end
      
      it "creates mappings" do
        subject.stub(:open).with("http://example.com/context").and_yield(@ctx)
        ec = subject.parse("http://example.com/context")
        ec.mappings.should produce({
          "name"     => "http://xmlns.com/foaf/0.1/name",
          "homepage" => "http://xmlns.com/foaf/0.1/homepage",
          "avatar"   => "http://xmlns.com/foaf/0.1/avatar"
        }, @debug)
      end
    end

    context "EvaluationContext" do
      it "uses a duplicate of that provided" do
        ec = subject.parse(StringIO.new(@ctx_json))
        ec.mappings.should produce({
          "name"     => "http://xmlns.com/foaf/0.1/name",
          "homepage" => "http://xmlns.com/foaf/0.1/homepage",
          "avatar"   => "http://xmlns.com/foaf/0.1/avatar"
        }, @debug)
      end
    end

    context "Array" do
      before(:all) do
        @ctx = [
          {"foo" => "http://example.com/foo"},
          {"bar" => "foo"}
        ]
      end
      
      it "merges definitions from each context" do
        ec = subject.parse(@ctx)
        ec.mappings.should produce({
          "foo" => "http://example.com/foo",
          "bar" => "http://example.com/foo"
        }, @debug)
      end
    end

    context "Hash" do
      it "extracts @language" do
        subject.parse({
          "@language" => "en"
        }).language.should produce("en", @debug)
      end

      it "maps term with IRI value" do
        subject.parse({
          "foo" => "http://example.com/"
        }).mappings.should produce({
          "foo" => "http://example.com/"
        }, @debug)
      end

      it "maps term with @id" do
        subject.parse({
          "foo" => {"@id" => "http://example.com/"}
        }).mappings.should produce({
          "foo" => "http://example.com/"
        }, @debug)
      end

      it "associates list coercion with predicate IRI" do
        subject.parse({
          "foo" => {"@id" => "http://example.com/", "@list" => true}
        }).lists.should produce({
          "http://example.com/" => true
        }, @debug)
      end

      it "associates @id coercion with predicate IRI" do
        subject.parse({
          "foo" => {"@id" => "http://example.com/", "@type" => "@id"}
        }).coercions.should produce({
          "http://example.com/" => "@id"
        }, @debug)
      end

      it "associates datatype coercion with predicate IRI" do
        subject.parse({
          "foo" => {"@id" => "http://example.com/", "@type" => RDF::XSD.string.to_s}
        }).coercions.should produce({
          "http://example.com/" => RDF::XSD.string.to_s
        }, @debug)
      end
      
      it "expands chains of term definition/use with string values" do
        subject.parse({
          "foo" => "bar",
          "bar" => "baz",
          "baz" => "http://example.com/"
        }).mappings.should produce({
          "foo" => "http://example.com/",
          "bar" => "http://example.com/",
          "baz" => "http://example.com/"
        }, @debug)
      end
    end
  end
    
  describe "#serialize" do
    it "uses provided context document" do
      ctx = StringIO.new(@ctx_json)
      def ctx.content_type; "application/ld+json"; end

      subject.stub(:open).with("http://example.com/context").and_yield(ctx)
      ec = subject.parse("http://example.com/context")
      ec.serialize.should produce({
        "@context" => "http://example.com/context"
      }, @debug)
    end
    
    it "uses provided context array" do
      ctx = [
        {"foo" => "bar"},
        {"baz" => "bob"}
      ]

      ec = subject.parse(ctx)
      ec.serialize.should produce({
        "@context" => ctx
      }, @debug)
    end
    
    it "uses provided context hash" do
      ctx = {"foo" => "bar"}

      ec = subject.parse(ctx)
      ec.serialize.should produce({
        "@context" => ctx
      }, @debug)
    end
    
    it "serializes @language" do
      subject.language = "en"
      subject.serialize.should produce({
        "@context" => {
          "@language" => "en"
        }
      }, @debug)
    end

    it "serializes term mappings" do
      subject.mapping("foo", "bar")
      subject.serialize.should produce({
        "@context" => {
          "foo" => "bar"
        }
      }, @debug)
    end
    
    it "serializes @type with dependent prefixes in a single context" do
      subject.mapping("xsd", RDF::XSD.to_uri)
      subject.mapping("homepage", RDF::FOAF.homepage)
      subject.coerce(RDF::FOAF.homepage, "@id")
      subject.serialize.should produce({
        "@context" => {
          "xsd" => RDF::XSD.to_uri,
          "homepage" => {"@id" => RDF::FOAF.homepage.to_s, "@type" => "@id"}
        }
      }, @debug)
    end
    
    it "serializes @list with @id definition in a single context" do
      subject.mapping("knows", RDF::FOAF.knows)
      subject.list(RDF::FOAF.knows, true)
      subject.serialize.should produce({
        "@context" => {
          "knows" => {"@id" => RDF::FOAF.knows.to_s, "@list" => true}
        }
      }, @debug)
    end
    
    it "serializes prefix with @type and @list" do
      subject.mapping("knows", RDF::FOAF.knows)
      subject.coerce(RDF::FOAF.knows, "@id")
      subject.list(RDF::FOAF.knows, true)
      subject.serialize.should produce({
        "@context" => {
          "knows" => {"@id" => RDF::FOAF.knows.to_s, "@type" => "@id", "@list" => true}
        }
      }, @debug)
    end
    
    it "serializes CURIE with @type" do
      subject.mapping("foaf", RDF::FOAF.to_uri)
      subject.list(RDF::FOAF.knows, true)
      subject.serialize.should produce({
        "@context" => {
          "foaf" => RDF::FOAF.to_uri,
          "foaf:knows" => {"@list" => true}
        }
      }, @debug)
    end
  end
  
  describe "#expand_iri" do
    before(:each) do
      subject.mapping("ex", RDF::URI("http://example.org/"))
      subject.mapping("", RDF::URI("http://empty/"))
    end

    {
      "absolute IRI" =>  ["http://example.org/", RDF::URI("http://example.org/")],
      "term" =>          ["ex",                  RDF::URI("http://example.org/")],
      "prefix:suffix" => ["ex:suffix",           RDF::URI("http://example.org/suffix")],
      "keyword" =>       ["@type",               "@type"],
      "empty" =>         [":suffix",             RDF::URI("http://empty/suffix")],
      "unmapped" =>      ["foo",                 RDF::URI("foo")],
    }.each do |title, (input,result)|
      it title do
        subject.expand_iri(input).should produce(result, @debug)
      end
    end
    it "bnode" do
      subject.expand_iri("_:a").should be_a(RDF::Node)
    end
  end
  
  describe "#compact_iri" do
    before(:each) do
      subject.mapping("ex", RDF::URI("http://example.org/"))
      subject.mapping("", RDF::URI("http://empty/"))
    end

    {
      "absolute IRI" =>  ["http://example.com/", RDF::URI("http://example.com/")],
      "term" =>          ["ex",                  RDF::URI("http://example.org/")],
      "prefix:suffix" => ["ex:suffix",           RDF::URI("http://example.org/suffix")],
      "keyword" =>       ["@type",               "@type"],
      "empty" =>         [":suffix",             RDF::URI("http://empty/suffix")],
      "unmapped" =>      ["foo",                 RDF::URI("foo")],
      "bnode" =>         ["_:a",                 RDF::Node("a")],
    }.each do |title, (result, input)|
      it title do
        subject.compact_iri(input).should produce(result, @debug)
      end
    end
  end
  
  describe "#expand_value" do
    before(:each) do
      subject.mapping("dc", RDF::DC.to_uri)
      subject.mapping("ex", RDF::URI("http://example.org/"))
      subject.mapping("foaf", RDF::FOAF.to_uri)
      subject.mapping("xsd", RDF::XSD.to_uri)
      subject.coerce(RDF::FOAF.age, RDF::XSD.integer)
      subject.coerce(RDF::FOAF.knows, "@id")
      subject.coerce(RDF::DC.created, RDF::XSD.date)
    end

    {
      "absolute IRI" =>   ["foaf:knows",  "http://example.com/",  {"@id" => "http://example.com/"}],
      "term" =>           ["foaf:knows",  "ex",                   {"@id" => "http://example.org/"}],
      "prefix:suffix" =>  ["foaf:knows",  "ex:suffix",            {"@id" => "http://example.org/suffix"}],
      "no IRI" =>         ["foo",         "http://example.com/",  "http://example.com/"],
      "no term" =>        ["foo",         "ex",                   "ex"],
      "no prefix" =>      ["foo",         "ex:suffix",            "ex:suffix"],
      "integer" =>        ["foaf:age",    "54",                   {"@literal" => "54", "@type" => RDF::XSD.integer.to_s}],
      "date " =>          ["dc:created",  "2011-12-27Z",          {"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
      "native boolean" => ["foo", true,                           {"@literal" => "true", "@type" => RDF::XSD.boolean.to_s}],
      "native integer" => ["foo", 1,                              {"@literal" => "1", "@type" => RDF::XSD.integer.to_s}],
      "native double" =>  ["foo", 1.1,                            {"@literal" => "1.1", "@type" => RDF::XSD.double.to_s}],
      "native date" =>    ["foo", Date.parse("2011-12-27Z"),      {"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
      "native time" =>    ["foo", Time.parse("10:11:12Z"),        {"@literal" => "10:11:12Z", "@type" => RDF::XSD.time.to_s}],
      "native dateTime" =>["foo", DateTime.parse("2011-12-27T10:11:12Z"), {"@literal" => "2011-12-27T10:11:12Z", "@type" => RDF::XSD.dateTime.to_s}],
      "rdf boolean" =>    ["foo", RDF::Literal(true),             {"@literal" => "true", "@type" => RDF::XSD.boolean.to_s}],
      "rdf integer" =>    ["foo", RDF::Literal(1),                {"@literal" => "1", "@type" => RDF::XSD.integer.to_s}],
      "rdf decimal" =>    ["foo", RDF::Literal::Decimal.new(1.1), {"@literal" => "1.1", "@type" => RDF::XSD.decimal.to_s}],
      "rdf double" =>     ["foo", RDF::Literal(1.1),              {"@literal" => "1.1", "@type" => RDF::XSD.double.to_s}],
      "rdf URI" =>        ["foo", RDF::URI("foo"),                {"@id" => "foo"}],
      "rdf date " =>      ["foo", RDF::Literal(Date.parse("2011-12-27Z")), {"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
    }.each do |title, (key, compacted, expanded)|
      it title do
        predicate = subject.expand_iri(key)
        subject.expand_value(predicate, compacted).should produce(expanded, @debug)
      end
    end
    
    context "@language" do
      {
        "no IRI" =>         ["foo",         "http://example.com/",  {"@literal" => "http://example.com/", "@language" => "en"}],
        "no term" =>        ["foo",         "ex",                   {"@literal" => "ex", "@language" => "en"}],
        "no prefix" =>      ["foo",         "ex:suffix",            {"@literal" => "ex:suffix", "@language" => "en"}],
        "native boolean" => ["foo",         true,                   {"@literal" => "true", "@type" => RDF::XSD.boolean.to_s}],
        "native integer" => ["foo",         1,                      {"@literal" => "1", "@type" => RDF::XSD.integer.to_s}],
        "native double" =>  ["foo",         1.1,                    {"@literal" => "1.1", "@type" => RDF::XSD.double.to_s}],
      }.each do |title, (key, compacted, expanded)|
        it title do
          subject.language = "en"
          predicate = subject.expand_iri(key)
          subject.expand_value(predicate, compacted).should produce(expanded, @debug)
        end
      end
    end
  end
  
  describe "compact_value" do
    before(:each) do
      subject.mapping("dc", RDF::DC.to_uri)
      subject.mapping("ex", RDF::URI("http://example.org/"))
      subject.mapping("foaf", RDF::FOAF.to_uri)
      subject.mapping("xsd", RDF::XSD.to_uri)
      subject.coerce(RDF::FOAF.age, RDF::XSD.integer)
      subject.coerce(RDF::FOAF.knows, "@id")
      subject.coerce(RDF::DC.created, RDF::XSD.date)
    end

    {
      "absolute IRI" =>   ["foaf:knows",  "http://example.com/",  {"@id" => "http://example.com/"}],
      "term" =>           ["foaf:knows",  "ex",                   {"@id" => "http://example.org/"}],
      "prefix:suffix" =>  ["foaf:knows",  "ex:suffix",            {"@id" => "http://example.org/suffix"}],
      "integer" =>        ["foaf:age",    54,                     {"@literal" => "54", "@type" => RDF::XSD.integer.to_s}],
      "date " =>          ["dc:created",  "2011-12-27Z",          {"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
      "no IRI" =>         ["foo", {"@id" => "http://example.com/"},  {"@id" => "http://example.com/"}],
      "no boolean" =>     ["foo", true,                           {"@literal" => "true", "@type" => RDF::XSD.boolean.to_s}],
      "no integer" =>     ["foo", 54,                             {"@literal" => "54", "@type" => RDF::XSD.integer.to_s}],
      "no date " =>       ["foo", {"@literal" => "2011-12-27Z", "@type" => "xsd:date"}, {"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
      "no string " =>     ["foo", "string",                       {"@literal" => "string"}],
    }.each do |title, (key, compacted, expanded)|
      it title do
        predicate = subject.expand_iri(key)
        subject.compact_value(predicate, expanded).should produce(compacted, @debug)
      end
    end
    
    context "@language" do
      {
        "@id"                            => ["foo", {"@id" => "foo"},                                   {"@id" => "foo"}],
        "integer"                        => ["foo", 54,                                                 {"@literal" => "54", "@type" => "xsd:integer"}],
        "date"                           => ["foo", {"@literal" => "2011-12-27Z","@type" => "xsd:date"},{"@literal" => "2011-12-27Z", "@type" => RDF::XSD.date.to_s}],
        "no lang"                        => ["foo", {"@literal" => "foo"  },                            {"@literal" => "foo"}],
        "same lang"                      => ["foo", "foo",                                              {"@literal" => "foo", "@language" => "en"}],
        "other lang"                     => ["foo",  {"@literal" => "foo", "@language" => "bar"},       {"@literal" => "foo", "@language" => "bar"}],
        "no lang with @type coercion"    => ["dc:created", {"@literal" => "foo"},                       {"@literal" => "foo"}],
        "no lang with @id coercion"      => ["foaf:knows", {"@literal" => "foo"},                       {"@literal" => "foo"}],
        "same lang with @type coercion"  => ["dc:created", {"@literal" => "foo"},                       {"@literal" => "foo"}],
        "same lang with @id coercion"    => ["foaf:knows", {"@literal" => "foo"},                       {"@literal" => "foo"}],
        "other lang with @type coercion" => ["dc:created", {"@literal" => "foo", "@language" => "bar"}, {"@literal" => "foo", "@language" => "bar"}],
        "other lang with @id coercion"   => ["foaf:knows", {"@literal" => "foo", "@language" => "bar"}, {"@literal" => "foo", "@language" => "bar"}],
      }.each do |title, (key, compacted, expanded)|
        it title do
          subject.language = "en"
          predicate = subject.expand_iri(key)
          subject.compact_value(predicate, expanded).should produce(compacted, @debug)
        end
      end
    end
    
    [[], true, false, 1, 1.1, "string"].each do |v|
      it "raises error given #{v.class}" do
        lambda {subject.compact_value("foo", v)}.should raise_error(JSON::LD::ProcessingError)
      end
    end
  end
end