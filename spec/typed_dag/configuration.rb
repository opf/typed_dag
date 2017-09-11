require 'spec_helper'

RSpec.describe TypedDag::Configuration do
  describe 'defining/accessing' do
    context 'for a single confg' do
      before do
        described_class.set edge_class_name: 'Relation',
                            node_class_name: 'Message',
                            types: { hierarchy: { up: { name: :parent, limit: 1 },
                                                  down: :children,
                                                  all_up: :ancestors,
                                                  all_down: :descendants },
                                     invalidate: { up: :invalidated_by,
                                                   down: :invalidates,
                                                   all_up: :all_invalidated_by,
                                                   all_down: :all_invalidates } }
      end

      it 'accesses the correct config for the edge name' do
        expect(described_class['Relation'].node_class_name)
          .to eql 'Message'
      end

      it 'accesses the correct config for the node name' do
        expect(described_class['Message'].edge_class_name)
          .to eql 'Relation'
      end

      it 'accesses the correct config for the edge class' do
        expect(described_class[Relation].node_class_name)
          .to eql 'Message'
      end

      it 'accesses the correct config for the node class' do
        expect(described_class[Message].edge_class_name)
          .to eql 'Relation'
      end
    end

    context 'for a multiple confgs' do
      before do
        described_class.set [
          {
            edge_class_name: 'Relation',
            node_class_name: 'Message',
            types: { hierarchy: { up: { name: :parent, limit: 1 },
                                  down: :children,
                                  all_up: :ancestors,
                                  all_down: :descendants },
                     invalidate: { up: :invalidated_by,
                                   down: :invalidates,
                                   all_up: :all_invalidated_by,
                                   all_down: :all_invalidates } }
          },
          {
            edge_class_name: 'Relation2',
            node_class_name: 'Message2',
            types: { hierarchy: { up: { name: :parent, limit: 1 },
                                  down: :children,
                                  all_up: :ancestors,
                                  all_down: :descendants },
                     invalidate: { up: :invalidated_by,
                                   down: :invalidates,
                                   all_up: :all_invalidated_by,
                                   all_down: :all_invalidates } }

          }
        ]
      end

      it 'accesses the correct config for the first edge name' do
        expect(described_class['Relation'].node_class_name)
          .to eql 'Message'
      end

      it 'accesses the correct config for the first node name' do
        expect(described_class['Message'].edge_class_name)
          .to eql 'Relation'
      end

      it 'accesses the correct config for the second edge name' do
        expect(described_class['Relation2'].node_class_name)
          .to eql 'Message2'
      end

      it 'accesses the correct config for the second node name' do
        expect(described_class['Message2'].edge_class_name)
          .to eql 'Relation2'
      end
    end
  end
end
