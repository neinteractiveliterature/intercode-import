# frozen_string_literal: true

require 'test_helper'

class EventliteCmsLayoutsDbTest < Minitest::Test
  include EventliteDbTestHelper

  def self.setup_db(db)
    db.create_table!(:events) do
      primary_key :id
      String :name
    end
    db.create_table!(:cms_layouts) do
      primary_key :id
      String  :name
      String  :content
      Integer :parent_id
      String  :parent_type
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:cms_layouts)
    db.drop_table?(:events)
  end

  def truncate_tables(db)
    db[:cms_layouts].delete
    db[:events].delete
  end

  def setup
    super
    @event_id = @db[:events].insert(name: 'Test Event')
  end

  def export_layouts(event_id = @event_id)
    IntercodeImport::Eventlite::Tables::CmsLayouts.new(@db, event_id).export!
  end

  def test_event_scoped_layout_exported
    @db[:cms_layouts].insert(name: 'Default', content: '<html>{{ content_for_layout }}</html>',
                             parent_type: 'Event', parent_id: @event_id)
    layouts = export_layouts
    assert_equal 1, layouts.size
    assert_equal 'Default', layouts.first[:name]
    assert_equal '<html>{{ content_for_layout }}</html>', layouts.first[:content]
  end

  def test_global_layout_included
    @db[:cms_layouts].insert(name: 'Global Layout', content: 'global', parent_type: nil, parent_id: nil)
    assert_equal 1, export_layouts.size
  end

  def test_other_event_layout_excluded
    other_event_id = @db[:events].insert(name: 'Other Event')
    @db[:cms_layouts].insert(name: 'Other Layout', content: 'other',
                             parent_type: 'Event', parent_id: other_event_id)
    assert_empty export_layouts
  end

  def test_id_map_keyed_by_layout_id
    lid = @db[:cms_layouts].insert(name: 'My Layout', content: '',
                                   parent_type: 'Event', parent_id: @event_id)
    table = IntercodeImport::Eventlite::Tables::CmsLayouts.new(@db, @event_id)
    table.export!
    assert_equal 'My Layout', table.id_map[lid]
  end
end
