describe BbCodes::Markdown::ListQuoteParserState do
  subject do
    described_class.new(
      text,
      index,
      nested_sequence,
      exit_sequence
    ).to_html
  end
  let(:index) { 0 }
  let(:nested_sequence) { '' }
  let(:exit_sequence) { nil }

  context 'list' do
    context 'single line' do
      let(:text) { ['- a', '+ a', '* a'].sample }
      it { is_expected.to eq ["<ul class='b-list'><li>a</li></ul>", nil] }
    end

    context 'sample' do
      let(:text) { '- qwe' }
      it { is_expected.to eq ["<ul class='b-list'><li>qwe</li></ul>", nil] }
    end

    context 'sample' do
      let(:text) { "- qwe\n" }
      it { is_expected.to eq ["<ul class='b-list'><li>qwe</li></ul>", nil] }
    end

    context 'item content on next line' do
      let(:text) { "- a\n  b" }
      it { is_expected.to eq ["<ul class='b-list'><li>a\nb</li></ul>", nil] }
    end

    context 'content after' do
      let(:text) { "- a\nb" }
      it { is_expected.to eq ["<ul class='b-list'><li>a</li></ul>b", nil] }
    end

    context 'multiline' do
      let(:text) { "- a\n- b" }
      it { is_expected.to eq ["<ul class='b-list'><li>a</li><li>b</li></ul>", nil] }
    end

    context 'moves through inner tags' do
      let(:text) { "- #{content}\n- c" }
      let(:content) do
        [
          "z [spoiler=x]x\nx[/spoiler]",
          "z [spoiler_v1]x\nx[/spoiler_v1]"
        ].sample
      end

      it do
        is_expected.to eq(
          ["<ul class='b-list'><li>#{content}</li><li>c</li></ul>", nil]
        )
      end

      context 'not closed bbcode' do
        let(:content) { "z [spoiler=x]x\nx[/div]" }
        it do
          is_expected.to eq(
            [
              "<ul class='b-list'><li>z [spoiler=x]x</li>" \
                "</ul>x[/div]<ul class='b-list'><li>c</li></ul>",
              nil
            ]
          )
        end
      end
    end
  end

  context 'blockquote' do
    context 'sample' do
      let(:text) { '> qwe' }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>qwe</div></blockquote>",
            nil
          ]
        )
      end
    end

    context 'sample' do
      let(:text) { '&gt; qwe' }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>qwe</div></blockquote>",
            nil
          ]
        )
      end
    end

    context 'multiline' do
      let(:text) { "> a\n> b\n> c" }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>a\nb\nc</div></blockquote>",
            nil
          ]
        )
      end
    end

    context 'nested blockquote' do
      let(:text) { '> > test' }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>" \
              "<blockquote class='b-quote-v2'><div class='quote-content'>test</div></blockquote>" \
              '</div></blockquote>',
            nil
          ]
        )
      end
    end

    context 'nested blockquote multiline' do
      let(:text) { "> > test\n> b" }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>" \
              "<blockquote class='b-quote-v2'><div class='quote-content'>test</div></blockquote>" \
              'b</div></blockquote>',
            nil
          ]
        )
      end
    end

    context 'with quotable', :focus do
      let(:text) { ">?a\n> b" }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quoteable'>a</div>" \
              "<div class='quote-content'>b</div></blockquote>",
            nil
          ]
        )
      end

      context 'w/o quote' do
        let(:text) { ">?a\nb" }
        # it { is_expected.to eq ['', text] }
      end
    end
  end

  context 'list + blockquote' do
    context 'sample' do
      let(:text) { '+ > test' }
      it do
        is_expected.to eq(
          [
            "<ul class='b-list'><li>" \
              "<blockquote class='b-quote-v2'><div class='quote-content'>test</div></blockquote>" \
              '</li></ul>',
            nil
          ]
        )
      end
    end

    context 'sample' do
      let(:text) { "+ > test\n  > 123" }
      it do
        is_expected.to eq(
          [
            "<ul class='b-list'><li>" \
              "<blockquote class='b-quote-v2'><div class='quote-content'>test\n123</div></blockquote>" \
              '</li></ul>',
            nil
          ]
        )
      end
    end

    context 'sample' do
      let(:text) { "> - test\n>   123" }
      it do
        is_expected.to eq(
          [
            "<blockquote class='b-quote-v2'><div class='quote-content'>" \
              "<ul class='b-list'><li>test\n123</li></ul>" \
              '</div></blockquote>',
            nil
          ]
        )
      end
    end

    context 'sample' do
      let(:text) { "- > 123\n> - 456\n>   789" }

      it do
        is_expected.to eq(
          [
            "<ul class='b-list'><li>" \
              "<blockquote class='b-quote-v2'><div class='quote-content'>" \
                '123' \
              '</div></blockquote></li></ul>' \
              "<blockquote class='b-quote-v2'><div class='quote-content'>" \
                "<ul class='b-list'><li>456\n789</li></ul>" \
              '</div></blockquote>',
            nil
          ]
        )
      end
    end
  end

  context 'exit sequence' do
    let(:text) { '- 1</h4>- 2' }
    let(:exit_sequence) { '</h4>' }

    it { is_expected.to eq ["<ul class='b-list'><li>1</li></ul>", '</h4>- 2'] }
  end
end
