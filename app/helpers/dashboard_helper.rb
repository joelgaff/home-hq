# Wes's shared view pieces (app.js: pstyle, avatar, dots; home.js: ring).
module DashboardHelper
  def person_style(person)
    person.style
  end

  def avatar(person, size = 48, cls = nil)
    tag.span(person.initial, class: [ "avatar", cls ].compact.join(" "),
      style: "#{person.style};width:#{size}px;height:#{size}px;font-size:#{(size * 0.46).round}px")
  end

  def dots(people, size = nil)
    tag.span(class: "dots") do
      safe_join(people.map { |p| tag.i(style: "#{p.style}#{size ? ";width:#{size}px;height:#{size}px" : ''}") })
    end
  end

  # Progress ring: done/total around a circle of `size` px.
  def ring(done, total, size)
    r = size / 2.0 - 5
    c = 2 * Math::PI * r
    f = total.positive? ? done.to_f / total : 0
    centre = size / 2.0
    tag.svg(class: "ring", width: size, height: size, viewBox: "0 0 #{size} #{size}") do
      tag.circle(cx: centre, cy: centre, r: r, class: "ring-bg") +
        tag.circle(cx: centre, cy: centre, r: r, class: "ring-fg", "stroke-dasharray": "#{c * f} #{c}", transform: "rotate(-90 #{centre} #{centre})")
    end
  end

  # Names for "Next up · Wes + Claudia" / "Everyone".
  def who_text(event)
    event.family? ? "Everyone" : event.attending_people.map(&:name).join(" + ")
  end
end
