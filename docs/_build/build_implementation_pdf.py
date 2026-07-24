from pathlib import Path
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_implementation_guide import stories  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Pilgrimage_2_Implementation_Stories.pdf"


def esc(text):
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def make_styles():
    base = getSampleStyleSheet()
    styles = {
        "Title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica",
            fontSize=26,
            leading=31,
            textColor=colors.HexColor("#181818"),
            alignment=TA_LEFT,
            spaceAfter=4,
        ),
        "Subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=14,
            leading=18,
            textColor=colors.HexColor("#555555"),
            spaceAfter=20,
        ),
        "Body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=10.4,
            leading=13.2,
            textColor=colors.HexColor("#181818"),
            spaceAfter=6,
        ),
        "Lead": ParagraphStyle(
            "Lead",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=10.7,
            leading=14,
            textColor=colors.HexColor("#181818"),
            backColor=colors.HexColor("#E8EEF5"),
            borderColor=colors.HexColor("#D6DEE8"),
            borderWidth=0.5,
            borderPadding=8,
            spaceAfter=16,
        ),
        "H1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=15.5,
            leading=19,
            textColor=colors.HexColor("#2E74B5"),
            spaceBefore=14,
            spaceAfter=8,
        ),
        "H2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12.8,
            leading=16,
            textColor=colors.HexColor("#2E74B5"),
            spaceBefore=12,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "H3": ParagraphStyle(
            "H3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=10.7,
            leading=13,
            textColor=colors.HexColor("#1F4D78"),
            spaceBefore=7,
            spaceAfter=3,
            keepWithNext=True,
        ),
        "Bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.8,
            leading=12.5,
            textColor=colors.HexColor("#181818"),
            leftIndent=10,
            spaceAfter=3,
        ),
        "Footer": ParagraphStyle(
            "Footer",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8.5,
            textColor=colors.HexColor("#666666"),
            alignment=TA_RIGHT,
        ),
    }
    return styles


def bullet_list(items, styles):
    return ListFlowable(
        [ListItem(Paragraph(esc(item), styles["Bullet"]), leftIndent=12) for item in items],
        bulletType="bullet",
        start="circle",
        leftIndent=16,
        bulletFontName="Helvetica",
        bulletFontSize=7,
        bulletOffsetY=1,
    )


def numbered_list(items, styles):
    return ListFlowable(
        [ListItem(Paragraph(esc(item), styles["Bullet"]), leftIndent=14) for item in items],
        bulletType="1",
        leftIndent=18,
        bulletFontName="Helvetica",
        bulletFontSize=9,
    )


def on_page(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8.5)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawString(inch, 0.55 * inch, "Pilgrimage_2 implementation stories")
    canvas.drawRightString(7.5 * inch, 0.55 * inch, f"Page {doc.page}")
    canvas.restoreState()


def build():
    styles = make_styles()
    doc = BaseDocTemplate(
        str(OUT),
        pagesize=letter,
        leftMargin=inch,
        rightMargin=inch,
        topMargin=0.85 * inch,
        bottomMargin=0.85 * inch,
        title="Pilgrimage_2 Implementation Stories",
        author="Codex",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=on_page)])

    story = []
    story.append(Paragraph("Pilgrimage_2", styles["Title"]))
    story.append(Paragraph("Implementation Stories and Build Guide", styles["Subtitle"]))
    story.append(
        Paragraph(
            "<b>Design philosophy.</b> This rebuild keeps the useful ideas from the older Pilgrimage project while avoiding the old coupling: one owner per responsibility, card data kept separate from visuals, signal-based system boundaries, explicit card states, and no hand system unless the game later proves it needs one.",
            styles["Lead"],
        )
    )

    story.append(Paragraph("Recommended Build Order", styles["H1"]))
    story.append(
        numbered_list(
            [
                "Stabilize the current card and slot foundation.",
                "Add board/grid helpers and a board controller.",
                "Add deck and journey-deck refill.",
                "Add actions before effects.",
                "Add game setup, movement, combat, and game-over rules.",
                "Build the real game scene and keep the card test scene as a lab.",
            ],
            styles,
        )
    )
    story.append(Spacer(1, 10))
    story.append(Paragraph("Story Details", styles["H1"]))

    for item in stories:
        story.append(Paragraph(esc(item["title"]), styles["H2"]))
        story.append(Paragraph("What this achieves", styles["H3"]))
        story.append(Paragraph(esc(item["achieves"]), styles["Body"]))
        story.append(Paragraph("Why this fits the rebuild", styles["H3"]))
        story.append(Paragraph(esc(item["why"]), styles["Body"]))
        story.append(Paragraph("Implementation guide", styles["H3"]))
        story.append(bullet_list(item["guide"], styles))
        story.append(Paragraph("Done when", styles["H3"]))
        story.append(bullet_list(item["done"], styles))
        story.append(Spacer(1, 8))

    story.append(PageBreak())
    story.append(Paragraph("Guardrails", styles["H1"]))
    story.append(
        Paragraph(
            "Use this checklist whenever a story touches shared architecture. It is deliberately small: the goal is to keep the rebuild clear while still moving quickly.",
            styles["Body"],
        )
    )
    story.append(
        bullet_list(
            [
                "One owner per responsibility: Input owns pointer drag, Board owns placement, Game owns rules, Actions own state mutation flow.",
                "Prefer data ids and factories over prebuilt scene references for cards and effects.",
                "Do not bring back the hand system as a hidden dependency.",
                "Do not let the card test scene become the main architecture.",
                "Effects should enqueue actions rather than directly editing unrelated cards.",
                "Keep debug helpers in src/tests or remove them once a behavior is stable.",
            ],
            styles,
        )
    )

    doc.build(story)
    print(OUT)


if __name__ == "__main__":
    build()
