#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
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

module IconsHelper
  ##
  # Create an <i> tag with the given icon class names
  # and make it aria-hidden since screenreaders otherwise
  # output the css `content` of the icon.
  def op_icon(classnames, title: nil)
    title = "title=\"#{h(title)}\"" unless title.nil?
    %(<i class="#{classnames}" #{title} aria-hidden="true"></i>).html_safe
  end

  def spot_icon(icon_name, title: nil, size: nil, inline: false, classnames: nil)
    classes = [
      "spot-icon",
      size ? "spot-icon_#{size}" : nil,
      inline ? "spot-icon_inline" : nil,
      "spot-icon_#{icon_name}",
      classnames
    ].compact.join(" ")

    content_tag(:span, title, class: classes)
  end

  ##
  # Icon wrapper with an invisible label
  def icon_wrapper(icon_class, label)
    content = op_icon(icon_class)
    content << content_tag(:span, label, class: "hidden-for-sighted")
    content
  end
end
