# Ecommerce Revenue Analytics (SQL + Power BI)

## What's this project about?
I'm analyzing the Olist Brazilian E-commerce dataset to find out what's actually driving revenue and where the business is losing money or reputation. Instead of just making a few charts, I'm building a full data pipeline from raw data to a clean star schema to answer real business questions.

## Progress So Far
- [x] **Defined the Mission:** Created 6 specific business pillars (Revenue, Customer Loyalty, Logistics Risk, etc.) to keep the analysis focused.
- [x] **Data Modeling:** Transformed the messy, 3NF operational data into a high-performance Star Schema.
- [x] **SQL Staging Layer:** Wrote the DDLs to clean the data, fix duplicates, and create new helpful metrics like `is_late`, `basket_size`, and `is_repeat_buyer`.
- [x] **Documentation:** Mapped out the "ambiguous" problems that management actually cares about in a dedicated doc.

## The Data Model
I moved away from the original complicated structure to a Star Schema. This makes the data much easier to work with and way faster for Power BI to process because it minimizes complex joins.

### Initial Data Model (Operational 3NF)
![Initial Data Model](docs/initial_data_model.png)

### Final Analytical Model (Star Schema)
![Final Data Model](docs/final_data_model.png)

## How I'm Analyzing It
I’ve broken the project into 5 main pillars to make sure I cover everything a business needs:
1. **Revenue & Growth:** Checking if our growth is real or just a temporary holiday spike.
2. **Customer Intelligence:** Figuring out why people buy once and never come back.
3. **Product Quality:** Finding the categories that make money but ruin our name with bad reviews.
4. **Unit Economics:** Seeing how much expensive shipping hurts our customer satisfaction.
5. **Strategic Risk:** Identifying if we rely too much on sellers in one region and if shipping to far-away states is a bottleneck.

## Next Steps
- [ ] Build the **Core Layer** views in SQL for each analysis pillar.
- [ ] Connect the clean views to **Power BI**.
- [ ] Build the interactive dashboard and write up the final business insights.

## Tech Stack
- **Database:** PostgreSQL (Data cleaning and modeling)
- **Visualization:** Power BI
- **Version Control:** Git
