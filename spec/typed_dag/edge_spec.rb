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
      let(:same_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant
      end

      before do
        same_relation
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
      let(:same_relation) do
        Relation.create ancestor: ancestor,
                        descendant: descendant,
                        invalidate: 1
      end

      before do
        same_relation
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
  end
end
