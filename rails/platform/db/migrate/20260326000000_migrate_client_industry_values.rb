class MigrateClientIndustryValues < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE clients SET industry = 'accommodation' WHERE industry = 'hotel';
      UPDATE clients SET industry = 'activity' WHERE industry = 'tour';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE clients SET industry = 'hotel' WHERE industry = 'accommodation';
      UPDATE clients SET industry = 'tour' WHERE industry = 'activity';
    SQL
  end
end
