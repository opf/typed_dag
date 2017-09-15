require 'spec_helper'

RSpec.describe 'Edge' do
  # using Relation, Message as the concrete classes

  let(:from) { Message.new text: 'from' }
  let(:to) { Message.new text: 'to' }
  let(:relation) do
    Relation.new from: from,
                 to: to,
                 hierarchy: 1
  end

  describe 'validations' do
    it 'is valid' do
      expect(relation)
        .to be_valid
    end

    context 'without an from' do
      let(:from) { nil }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'states the error' do
        relation.valid?

        expect(relation.errors.details[:from])
          .to match_array([error: :blank])
      end
    end

    context 'without a to' do
      let(:to) { nil }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'states the error' do
        relation.valid?

        expect(relation.errors.details[:to])
          .to match_array([error: :blank])
      end
    end

    context 'with a relation already in place between the two nodes' do
      let!(:same_relation) do
        Relation.create from: from,
                        to: to
      end

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'notes the uniqueness constraint' do
        relation.valid?

        expect(relation.errors.details[:from].first[:error])
          .to eql :taken
      end
    end

    context 'with a relation already in place between the two nodes having a different type' do
      let!(:same_relation) do
        Relation.create from: from,
                        to: to,
                        invalidate: 1
      end

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'notes the uniqueness constraint' do
        relation.valid?

        expect(relation.errors.details[:from].first[:error])
          .to eql :taken
      end
    end

    context 'with a closure relation already in place between the two nodes (same type)' do
      let!(:closure_relation) do
        Relation.create from: from,
                        to: to,
                        invalidate: 2
      end

      it 'is valid' do
        expect(relation)
          .to be_valid
      end
    end

    context 'with a closure relation already in place between the two nodes (mixed type)' do
      let!(:closure_relation) do
        Relation.create from: from,
                        to: to,
                        invalidate: 1,
                        hierarchy: 1
      end

      it 'is valid' do
        expect(relation)
          .to be_valid
      end
    end

    context 'with a relation in place but in the other direction' do
      let(:inverse_relation) do
        Relation.create to: from,
                        from: to,
                        hierarchy: 1
      end

      before do
        inverse_relation
      end

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end
    end

    context 'with A - B - C and trying to connect C and A' do
      let(:a) { Message.create text: 'A' }
      let(:b) { Message.create text: 'B' }
      let(:c) { Message.create text: 'C' }
      let!(:relationAB) do
        Relation.create from: a,
                        to: b,
                        hierarchy: 1
      end
      let!(:relationBC) do
        Relation.create from: b,
                        to: c,
                        hierarchy: 1
      end
      let(:from) { c }
      let(:to) { b }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end
    end

    context 'with A - B - C (different type) already related and trying to connect C and A' do
      let(:a) { Message.create text: 'A' }
      let(:b) { Message.create text: 'B' }
      let(:c) { Message.create text: 'C' }
      let!(:relationAB) do
        Relation.create from: a,
                        to: b,
                        invalidate: 1
      end
      let!(:relationBC) do
        Relation.create from: b,
                        to: c,
                        hierarchy: 1
      end
      let(:from) { c }
      let(:to) { b }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end
    end
  end
end
