object @experiment
attribute :id, :name, :qpcr, :started_at, :completed_at, :completion_status, :created_at

node(:errors, :unless => lambda { |obj| obj.errors.empty? }) do |o|
	o.errors
end