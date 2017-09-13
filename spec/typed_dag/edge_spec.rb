require 'spec_helper'

RSpec.describe 'Edge' do
  # using Relation, Message as the concrete classes

  let(:ancestor) { Message.new text: 'ancestor' }
  let(:descendant) { Message.new text: 'descendant' }
  let(:relation) do
    Relation.new ancestor: ancestor,
                 descendant: descendant,
                 hierarchy: 1
  end

  describe 'validations' do
    it 'is valid' do
      expect(relation)
        .to be_valid
    end

    context 'without an ancestor' do
      let(:ancestor) { nil }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'states the error' do
        relation.valid?

        expect(relation.errors.details[:ancestor])
          .to match_array([error: :blank])
      end
    end

    context 'without a descendant' do
      let(:descendant) { nil }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'states the error' do
        relation.valid?

        expect(relation.errors.details[:descendant])
          .to match_array([error: :blank])
      end
    end

    context 'with a relation already in place between the two nodes' do
      let!(:same_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant
      end

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'notes the uniqueness constraint' do
        relation.valid?

        expect(relation.errors.details[:ancestor].first[:error])
          .to eql :taken
      end
    end

    context 'with a relation already in place between the two nodes having a different type' do
      let!(:same_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant,
                        invalidate: 1
      end

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end

      it 'notes the uniqueness constraint' do
        relation.valid?

        expect(relation.errors.details[:ancestor].first[:error])
          .to eql :taken
      end
    end

    context 'with a closure relation already in place between the two nodes (same type)' do
      let!(:closure_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant,
                        invalidate: 2
      end

      it 'is valid' do
        expect(relation)
          .to be_valid
      end
    end

    context 'with a closure relation already in place between the two nodes (mixed type)' do
      let!(:closure_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant,
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
        Relation.create descendant: ancestor,
                        ancestor: descendant,
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
        Relation.create ancestor: a,
                        descendant: b,
                        hierarchy: 1
      end
      let!(:relationBC) do
        Relation.create ancestor: b,
                        descendant: c,
                        hierarchy: 1
      end
      let(:ancestor) { c }
      let(:descendant) { b }

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
        Relation.create ancestor: a,
                        descendant: b,
                        invalidate: 1
      end
      let!(:relationBC) do
        Relation.create ancestor: b,
                        descendant: c,
                        hierarchy: 1
      end
      let(:ancestor) { c }
      let(:descendant) { b }

      it 'is invalid' do
        expect(relation)
          .to be_invalid
      end
    end
  end
end
