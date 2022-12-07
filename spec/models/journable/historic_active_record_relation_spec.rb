#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

describe Journable::HistoricActiveRecordRelation do
  # See: https://github.com/opf/openproject/pull/11243

  let(:before_monday) { "2022-01-01".to_datetime }
  let(:monday) { "2022-08-01".to_datetime }
  let(:tuesday) { "2022-08-02".to_datetime }
  let(:wednesday) { "2022-08-03".to_datetime }
  let(:thursday) { "2022-08-04".to_datetime }
  let(:friday) { "2022-08-05".to_datetime }

  let(:project) { create(:project) }
  let!(:work_package) do
    new_work_package = create(:work_package, description: "The work package as it is since Friday", estimated_hours: 10, project:)
    new_work_package.update_columns created_at: monday
    new_work_package
  end
  let(:journable) { work_package }

  let(:monday_journal) do
    create_journal(journable: work_package, timestamp: monday,
                   attributes: { description: "The work package as it has been on Monday", estimated_hours: 5 })
  end
  let(:wednesday_journal) do
    create_journal(journable: work_package, timestamp: wednesday,
                   attributes: { description: "The work package as it has been on Wednesday", estimated_hours: 10 })
  end
  let(:friday_journal) do
    create_journal(journable: work_package, timestamp: friday,
                   attributes: { description: "The work package as it is since Friday", estimated_hours: 10 })
  end

  let(:relation) { WorkPackage.all }
  let(:historic_relation) { relation.at_timestamp(wednesday) }

  def create_journal(journable:, timestamp:, attributes: {})
    work_package_attributes = work_package.attributes.except("id")
    journal_attributes = work_package_attributes \
        .extract!(*Journal::WorkPackageJournal.attribute_names) \
        .symbolize_keys.merge(attributes)
    create(:work_package_journal,
           journable:, created_at: timestamp, updated_at: timestamp,
           data: build(:journal_work_package_journal, journal_attributes))
  end

  before do
    work_package.journals.destroy_all
    monday_journal
    wednesday_journal
    friday_journal
    work_package.reload
  end

  subject { historic_relation }

  describe "#where" do
    describe "project_id in array (Arel::Nodes::HomogeneousIn)" do
      let(:relation) { WorkPackage.where(project_id: [project.id, 1, 2, 3]) }

      describe "#to_sql" do
        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "\"work_package_journals\".\"project_id\" IN (#{project.id}, 1, 2, 3)"
        end
      end

      describe "#to_a" do
        it "returns the requested work package" do
          expect(subject.to_a).to include work_package
        end
      end
    end

    describe "project_id not in array (Arel::Nodes::HomogeneousIn)" do
      let(:relation) { WorkPackage.where.not(project_id: [9999, 999]) }

      describe "#to_sql" do
        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "\"work_package_journals\".\"project_id\" NOT IN (9999, 999)"
        end
      end

      describe "#to_a" do
        it "returns the requested work package" do
          expect(subject.to_a).to include work_package
        end
      end
    end

    describe "id in array (Arel::Nodes::HomogeneousIn)" do
      let(:relation) { WorkPackage.where(id: [work_package.id, 999, 9999]) }

      describe "#to_sql" do
        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "\"journals\".\"journable_id\" IN (#{work_package.id}, 999, 9999)"
        end
      end

      describe "#to_a" do
        it "returns the requested work package" do
          expect(subject.to_a).to include work_package
        end
      end
    end

    describe "id in subquery (Arel::Nodes::In)" do
      let(:relation) { WorkPackage.where(id: WorkPackage.where(id: [work_package.id, 999, 9999])) }

      describe "#to_sql" do
        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "\"journals\".\"journable_id\" IN (SELECT \"work_packages\".\"id\""
        end
      end

      describe "#to_a" do
        it "returns the requested work package" do
          expect(subject.to_a).to include work_package
        end
      end
    end

    describe "sql string (as used by Query#statement)" do
      let(:relation) { WorkPackage.where("(work_packages.description ILIKE '%been on Wednesday%')") }

      it "transforms the table name" do
        expect(subject.to_sql).to include "work_package_journals.description ILIKE"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end

      describe "when the sql where statement includes work_package.id" do
        # This is used, for example, in 'follows' relations.
        let(:relation) { WorkPackage.where("(work_packages.id IN (#{work_package.id}))") }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "journals.journable_id IN (#{work_package.id})"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end

      describe "when the sql where statement includes \"work_package\".\"id\"" do
        # This is used in the manual-sorting feature.
        let(:relation) { WorkPackage.where("(\"work_packages\".\"id\" IN (#{work_package.id}))") }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include "\"journals\".\"journable_id\" IN (#{work_package.id})"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end
    end

    describe "foo OR bar (Arel::Nodes::Grouping)" do
      # https://github.com/opf/openproject/pull/11678#issuecomment-1328011996
      let(:relation) do
        WorkPackage.where(subject: "Foo").or(
          WorkPackage.where(description: "The work package as it has been on Wednesday")
        )
      end

      it "transforms the expression to query the correct table" do
        expect(subject.to_sql).to include \
          "\"work_package_journals\".\"subject\" = 'Foo' OR " \
          "\"work_package_journals\".\"description\" = 'The work package as it has been on Wednesday'"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end

    describe "work_packages.updated_at > ?" do
      # as used by spec/features/work_packages/timeline/timeline_dates_spec.rb
      let(:relation) { WorkPackage.where("work_packages.updated_at > '2022-01-01'") }

      it "transforms the expression to query the correct table" do
        expect(subject.to_sql).to include \
          "journals.created_at > '2022-01-01'"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end

      describe "when using quotation marks" do
        let(:relation) { WorkPackage.where("\"work_packages\".\"updated_at\" > '2022-01-01'") }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include \
            "\"journals\".\"created_at\" > '2022-01-01'"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end

      describe "when using a hash" do
        let(:relation) { WorkPackage.where(work_packages: { updated_at: ("2022-01-01".to_datetime).. }) }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include \
            "\"journals\".\"created_at\" >= '2022-01-01"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end
    end

    describe "work_packages.created_at > ?" do
      # as used by spec/features/work_packages/table/queries/filter_spec.rb
      let(:relation) { WorkPackage.where("work_packages.created_at > '2022-01-01'") }

      it "transforms the expression to query the correct table" do
        expect(subject.to_sql).to include \
          "journables.created_at > '2022-01-01'"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end

      describe "when using quotation marks" do
        let(:relation) { WorkPackage.where("\"work_packages\".\"created_at\" > '2022-01-01'") }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include \
            "\"journables\".\"created_at\" > '2022-01-01'"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end

      describe "when using a hash" do
        let(:relation) { WorkPackage.where(work_packages: { created_at: ("2022-01-01".to_datetime).. }) }

        it "transforms the expression to query the correct table" do
          expect(subject.to_sql).to include \
            "\"journables\".\"created_at\" >= '2022-01-01"
        end

        it "returns the requested work package" do
          expect(subject).to include work_package
        end
      end
    end
  end

  describe "#order" do
    let(:relation) { WorkPackage.order(description: :desc) }

    it "transforms the table name" do
      expect(subject.to_sql).to include "\"work_package_journals\".\"description\" DESC"
    end

    it "returns the requested work package" do
      expect(subject).to include work_package
    end

    describe "manual order clause" do
      let(:relation) { WorkPackage.order("work_packages.description DESC") }

      it "transforms the table name" do
        expect(subject.to_sql).to include "work_package_journals.description DESC"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end

    describe "manual order clause using work_packages.id" do
      # This is used in the manual-sorting feature.
      let(:relation) { WorkPackage.order("work_packages.id DESC") }

      it "transforms the table name" do
        expect(subject.to_sql).to include "journals.journable_id DESC"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end

    describe "order clause with work_packages.id" do
      let(:relation) { WorkPackage.order(id: :desc) }

      it "transforms the table name" do
        expect(subject.to_sql).to include "\"journals\".\"journable_id\" DESC"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end

    describe "several order clauses" do
      let(:relation) { WorkPackage.order(subject: :asc, id: :desc) }

      it "transforms the table name" do
        expect(subject.to_sql).to include "\"work_package_journals\".\"subject\" ASC"
        expect(subject.to_sql).to include "\"journals\".\"journable_id\" DESC"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end
  end

  describe "#joins" do
    describe "using active record" do
      let(:relation) { WorkPackage.joins(:time_entries) }

      before { work_package.time_entries << create(:time_entry) }

      it "transforms the table name" do
        expect(subject.to_sql).to include \
          "JOIN \"time_entries\" ON \"time_entries\".\"work_package_id\" = \"journals\".\"journable_id\""
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end

    describe "using a manual sql expression" do
      # This is used in the manual-sorting feature.
      let(:relation) do
        WorkPackage \
          .joins("LEFT OUTER JOIN ordered_work_packages ON ordered_work_packages.work_package_id = work_packages.id")
      end

      it "transforms the table name" do
        expect(subject.to_sql).to include \
          "LEFT OUTER JOIN ordered_work_packages ON ordered_work_packages.work_package_id = journals.journable_id"
      end

      it "returns the requested work package" do
        expect(subject).to include work_package
      end
    end
  end
end
