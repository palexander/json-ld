# coding: utf-8
$:.unshift "."
require 'spec_helper'

describe JSON::LD::API do
  before(:each) { @debug = []}

  describe ".compact" do
    {
      "prefix" => {
        :input => {
          "@id" => "http://example.com/a",
          "http://example.com/b" => {"@id" => "http://example.com/c"}
        },
        :context => {"ex" => "http://example.com/"},
        :output => {
          "@context" => {"ex" => "http://example.com/"},
          "@id" => "ex:a",
          "ex:b" => {"@id" => "ex:c"}
        }
      },
      "term" => {
        :input => {
          "@id" => "http://example.com/a",
          "http://example.com/b" => {"@id" => "http://example.com/c"}
        },
        :context => {"b" => "http://example.com/b"},
        :output => {
          "@context" => {"b" => "http://example.com/b"},
          "@id" => "http://example.com/a",
          "b" => {"@id" => "http://example.com/c"}
        }
      },
      "integer value" => {
        :input => {
          "@id" => "http://example.com/a",
          "http://example.com/b" => {"@value" => 1}
        },
        :context => {"b" => "http://example.com/b"},
        :output => {
          "@context" => {"b" => "http://example.com/b"},
          "@id" => "http://example.com/a",
          "b" => 1
        }
      },
      "boolean value" => {
        :input => {
          "@id" => "http://example.com/a",
          "http://example.com/b" => {"@value" => true}
        },
        :context => {"b" => "http://example.com/b"},
        :output => {
          "@context" => {"b" => "http://example.com/b"},
          "@id" => "http://example.com/a",
          "b" => true
        }
      },
      "@id" => {
        :input => {"@id" => "http://example.org/test#example"},
        :context => {},
        :output => {"@graph" => []}
      },
      "@id coercion" => {
        :input => {
          "@id" => "http://example.com/a",
          "http://example.com/b" => {"@id" => "http://example.com/c"}
        },
        :context => {"b" => {"@id" => "http://example.com/b", "@type" => "@id"}},
        :output => {
          "@context" => {"b" => {"@id" => "http://example.com/b", "@type" => "@id"}},
          "@id" => "http://example.com/a",
          "b" => "http://example.com/c"
        }
      },
      "xsd:date coercion" => {
        :input => {
          "http://example.com/b" => {"@value" => "2012-01-04", "@type" => RDF::XSD.date.to_s}
        },
        :context => {
          "xsd" => RDF::XSD.to_s,
          "b" => {"@id" => "http://example.com/b", "@type" => "xsd:date"}
        },
        :output => {
          "@context" => {
            "xsd" => RDF::XSD.to_s,
            "b" => {"@id" => "http://example.com/b", "@type" => "xsd:date"}
          },
          "b" => "2012-01-04"
        }
      },
      "@list coercion" => {
        :input => {
          "http://example.com/b" => {"@list" => ["c", "d"]}
        },
        :context => {"b" => {"@id" => "http://example.com/b", "@container" => "@list"}},
        :output => {
          "@context" => {"b" => {"@id" => "http://example.com/b", "@container" => "@list"}},
          "b" => ["c", "d"]
        }
      },
      "@list coercion (integer)" => {
        :input => {
          "http://example.com/term" => [
            {"@list" => [1]},
          ]
        },
        :context => {
          "term4" => {"@id" => "http://example.com/term", "@container" => "@list"},
          "@language" => "de"
        },
        :output => {
          "@context" => {
            "term4" => {"@id" => "http://example.com/term", "@container" => "@list"},
            "@language" => "de"
          },
          "term4" => [1],
        }
      },
      "@set coercion" => {
        :input => {
          "http://example.com/b" => {"@set" => ["c"]}
        },
        :context => {"b" => {"@id" => "http://example.com/b", "@container" => "@set"}},
        :output => {
          "@context" => {"b" => {"@id" => "http://example.com/b", "@container" => "@set"}},
          "b" => ["c"]
        }
      },
      "empty @set coercion" => {
        :input => {
          "http://example.com/b" => []
        },
        :context => {"b" => {"@id" => "http://example.com/b", "@container" => "@set"}},
        :output => {
          "@context" => {"b" => {"@id" => "http://example.com/b", "@container" => "@set"}},
          "b" => []
        }
      },
      "empty term" => {
        :input => {
          "@id" => "http://example.com/",
          "@type" => "#{RDF::RDFS.Resource}"
        },
        :context => {"" => "http://example.com/"},
        :output => {
          "@context" => {"" => "http://example.com/"},
          "@id" => "",
          "@type" => "#{RDF::RDFS.Resource}"
        },
      },
      "@type with string @id" => {
        :input => {
          "@id" => "http://example.com/",
          "@type" => "#{RDF::RDFS.Resource}"
        },
        :context => {},
        :output => {
          "@id" => "http://example.com/",
          "@type" => "#{RDF::RDFS.Resource}"
        },
      },
      "@type with array @id" => {
        :input => {
          "@id" => "http://example.com/",
          "@type" => ["#{RDF::RDFS.Resource}"]
        },
        :context => {},
        :output => {
          "@id" => "http://example.com/",
          "@type" => "#{RDF::RDFS.Resource}"
        },
      },
      "default language" => {
        :input => {
          "http://example.com/term" => [
            "v5",
            {"@value" => "plain literal"}
          ]
        },
        :context => {
          "term5" => {"@id" => "http://example.com/term", "@language" => nil},
          "@language" => "de"
        },
        :output => {
          "@context" => {
            "term5" => {"@id" => "http://example.com/term", "@language" => nil},
            "@language" => "de"
          },
          "term5" => [ "v5", "plain literal" ]
        }
      },
    }.each_pair do |title, params|
      it title do
        jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
        jld.should produce(params[:output], @debug)
      end
    end

    context "keyword aliasing" do
      {
        "@id" => {
          :input => {
            "@id" => "",
            "@type" => "#{RDF::RDFS.Resource}"
          },
          :context => {"id" => "@id"},
          :output => {
            "@context" => {"id" => "@id"},
            "id" => "",
            "@type" => "#{RDF::RDFS.Resource}"
          }
        },
        "@type" => {
          :input => {
            "@type" => RDF::RDFS.Resource.to_s,
            "http://example.org/foo" => {"@value" => "bar", "@type" => "http://example.com/type"}
          },
          :context => {"type" => "@type"},
          :output => {
            "@context" => {"type" => "@type"},
            "type" => RDF::RDFS.Resource.to_s,
            "http://example.org/foo" => {"@value" => "bar", "type" => "http://example.com/type"}
          }
        },
        "@language" => {
          :input => {
            "http://example.org/foo" => {"@value" => "bar", "@language" => "baz"}
          },
          :context => {"language" => "@language"},
          :output => {
            "@context" => {"language" => "@language"},
            "http://example.org/foo" => {"@value" => "bar", "language" => "baz"}
          }
        },
        "@value" => {
          :input => {
            "http://example.org/foo" => {"@value" => "bar", "@language" => "baz"}
          },
          :context => {"literal" => "@value"},
          :output => {
            "@context" => {"literal" => "@value"},
            "http://example.org/foo" => {"literal" => "bar", "@language" => "baz"}
          }
        },
        "@list" => {
          :input => {
            "http://example.org/foo" => {"@list" => ["bar"]}
          },
          :context => {"list" => "@list"},
          :output => {
            "@context" => {"list" => "@list"},
            "http://example.org/foo" => {"list" => ["bar"]}
          }
        },
      }.each do |title, params|
        it title do
          jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
          jld.should produce(params[:output], @debug)
        end
      end
    end

    context "term selection" do
      {
        "Uses term with nil language when two terms conflict on language" => {
          :input => [{
            "http://example.com/term" => {"@value" => "v1", "@language" => nil}
          }],
          :context => {
            "term5" => {"@id" => "http://example.com/term","@language" => nil},
            "@language" => "de"
          },
          :output => {
            "@context" => {
              "term5" => {"@id" => "http://example.com/term","@language" => nil},
              "@language" => "de"
            },
            "term5" => "v1",
          }
        },
        "Uses subject alias" => {
          :input => [{
            "@id" => "http://example.com/id1",
            "http://example.com/id1" => {"@value" => "foo", "@language" => "de"}
          }],
          :context => {
            "id1" => "http://example.com/id1",
            "@language" => "de"
          },
          :output => {
            "@context" => {
              "id1" => "http://example.com/id1",
              "@language" => "de"
            },
            "@id" => "id1",
            "id1" => "foo"
          }
        }
      }.each_pair do |title, params|
        it title do
          input = params[:input].is_a?(String) ? JSON.parse(params[:input]) : params[:input]
          ctx = params[:context].is_a?(String) ? JSON.parse(params[:context]) : params[:context]
          output = params[:output].is_a?(String) ? JSON.parse(params[:output]) : params[:output]
          jld = JSON::LD::API.compact(input, ctx, nil, :debug => @debug)
          jld.should produce(output, @debug)
        end
      end
    end

    context "context as value" do
      it "includes the context in the output document" do
        ctx = {
          "foo" => "http://example.com/"
        }
        input = {
          "http://example.com/" => "bar"
        }
        expected = {
          "@context" => {
            "foo" => "http://example.com/"
          },
          "foo" => "bar"
        }
        jld = JSON::LD::API.compact(input, ctx, nil, :debug => @debug, :validate => true)
        jld.should produce(expected, @debug)
      end
    end

    context "context as reference" do
      it "uses referenced context" do
        ctx = StringIO.new(%q({"@context": {"b": "http://example.com/b"}}))
        input = {
          "http://example.com/b" => "c"
        }
        expected = {
          "@context" => "http://example.com/context",
          "b" => "c"
        }
        RDF::Util::File.stub(:open_file).with("http://example.com/context").and_yield(ctx)
        jld = JSON::LD::API.compact(input, "http://example.com/context", nil, :debug => @debug, :validate => true)
        jld.should produce(expected, @debug)
      end
    end

    context "@list" do
      {
        "1 term 2 lists 2 languages" => {
          :input => [{
            "http://example.com/foo" => [
              {"@list" => [{"@value" => "en", "@language" => "en"}]},
              {"@list" => [{"@value" => "de", "@language" => "de"}]}
            ]
          }],
          :context => {
            "foo_en" => {"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "en"},
            "foo_de" => {"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "de"}
          },
          :output => {
            "@context" => {
              "foo_en" => {"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "en"},
              "foo_de" => {"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "de"}
            },
            "foo_en" => ["en"],
            "foo_de" => ["de"]
          }
        },
      }.each_pair do |title, params|
        it title do
          jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
          jld.should produce(params[:output], @debug)
        end
      end
    end

    context "language maps" do
      {
        "compact-0024" => {
          :input => [
            {
              "@id" => "http://example.com/queen",
              "http://example.com/vocab/label" => [
                {"@value" => "The Queen", "@language" => "en"},
                {"@value" => "Die Königin", "@language" => "de"},
                {"@value" => "Ihre Majestät", "@language" => "de"}
              ]
            }
          ],
          :context => {
            "vocab" => "http://example.com/vocab/",
            "label" => {"@id" => "vocab:label", "@container" => "@language"}
          },
          :output => {
            "@context" => {
              "vocab" => "http://example.com/vocab/",
              "label" => {"@id" => "vocab:label", "@container" => "@language"}
            },
            "@id" => "http://example.com/queen",
            "label" => {
              "en" => "The Queen",
              "de" => ["Die Königin", "Ihre Majestät"]
            }
          }
        },
      }.each_pair do |title, params|
        it title do
          jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
          jld.should produce(params[:output], @debug)
        end
      end
    end

    context "property generators" do
      {
        "exactly matching" => {
          :input => [{
            "http://example.com/foo" => [{"@value" => "baz"}],
            "http://example.com/bar"=> [{"@value" => "baz"}],
          }],
          :context => {
            "foobar" => {"@id" => ["http://example.com/foo", "http://example.com/bar"]}
          },
          :output => {
            "@context" => {
              "foobar" => {"@id" => ["http://example.com/foo", "http://example.com/bar"]}
            },
            "foobar" => "baz"
          }
        },
        "overlapping" => {
          :input => [{
            "http://example.com/foo" => [{"@value" => "baz"}, {"@value" => "baz1"}],
            "http://example.com/bar"=> [{"@value" => "baz"}, {"@value" => "baz2"}],
          }],
          :context => {
            "foobar" => {"@id" => ["http://example.com/foo", "http://example.com/bar"]}
          },
          :output => {
            "@context" => {
              "foobar" => {"@id" => ["http://example.com/foo", "http://example.com/bar"]}
            },
            "foobar" => "baz",
            "http://example.com/foo" => "baz1",
            "http://example.com/bar" => "baz2"
          }
        },
        "compact-0031" => {
          :input => JSON.parse(%q([{
             "@id": "http://example.com/node/1",
             "http://example.com/vocab/field_related": [{
                "@id": "http://example.com/node/this-is-related-news"
             }],
             "http://schema.org/about": [{
                "@id": "http://example.com/node/this-is-related-news"
             }, {
                "@id": "http://example.com/term/this-is-a-tag"
             }],
             "http://example.com/vocab/field_tags": [{
                "@id": "http://example.com/term/this-is-a-tag"
             }]
          }])),
          :context => JSON.parse(%q({
            "site": "http://example.com/",
            "field_tags": {
              "@id": [ "site:vocab/field_tags", "http://schema.org/about" ],
              "@container": "@set"
            },
            "field_related": {
              "@id": [ "site:vocab/field_related", "http://schema.org/about" ]
            }
          })),
          :output => JSON.parse(%q({
            "@context": {
              "site": "http://example.com/",
              "field_tags": {
                "@id": [
                  "site:vocab/field_tags",
                  "http://schema.org/about"
                ],
                "@container": "@set"
              },
              "field_related": {
                "@id": [
                  "site:vocab/field_related",
                  "http://schema.org/about"
                ]
              }
            },
            "@id": "site:node/1",
            "field_tags": [{"@id": "site:term/this-is-a-tag"}],
            "field_related": {"@id": "site:node/this-is-related-news"}
          })),
        },
      }.each_pair do |title, params|
        it title do
          jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
          jld.should produce(params[:output], @debug)
        end
      end
    end

    context "@graph" do
      {
        "Uses @graph given mutliple inputs" => {
          :input => [
            {"http://example.com/foo" => ["foo"]},
            {"http://example.com/bar" => ["bar"]}
          ],
          :context => {"ex" => "http://example.com/"},
          :output => {
            "@context" => {"ex" => "http://example.com/"},
            "@graph" => [
              {"ex:foo"  => "foo"},
              {"ex:bar" => "bar"}
            ]
          }
        },
      }.each_pair do |title, params|
        it title do
          jld = JSON::LD::API.compact(params[:input], params[:context], nil, :debug => @debug)
          jld.should produce(params[:output], @debug)
        end
      end
    end

    context "exceptions" do
      {
        "@list containing @list" => {
          :input => {
            "http://example.org/foo" => {"@list" => [{"@list" => ["baz"]}]}
          },
          :exception => JSON::LD::ProcessingError::ListOfLists
        },
        "@list containing @list (with coercion)" => {
          :input => {
            "@context" => {"http://example.org/foo" => {"@container" => "@list"}},
            "http://example.org/foo" => [{"@list" => ["baz"]}]
          },
          :exception => JSON::LD::ProcessingError::ListOfLists
        },
      }.each do |title, params|
        it title do
          lambda {JSON::LD::API.compact(params[:input], {}, nil)}.should raise_error(params[:exception])
        end
      end
    end
  end
end
